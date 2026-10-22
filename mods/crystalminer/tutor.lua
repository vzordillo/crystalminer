-- The in-game tutor, over raw HTTP: the Claude API (default) or any OpenAI-compatible server, such
-- as Ollama running a free open-source model locally (see "Providers" below).
--
-- The model only explains and translates. /ask answers from the reviewed text in content.lua;
-- /symmetry only picks a point-group symbol, which the symmetry engine then checks.
--
-- Loaded with loadfile(...)(symmetry, content).

local S, content = ...

local T = {}

-- Verified against https://platform.claude.com/docs/en/models/overview (October 2026).
T.MODEL = "claude-opus-5-5"
T.URL = "https://api.anthropic.com/v1/messages"
-- Hard cap on output per request (thinking plus reply). Opus 5.5 always thinks a little, even at
-- low effort; 4096 leaves ample room for an 80-word answer while bounding the cost of one request.
T.MAX_TOKENS = 4096

-- Cost and abuse limits.
T.COOLDOWN = 20        -- seconds between requests from one player
T.MAX_IN_FLIGHT = 3    -- requests waiting for the API at once, across the whole server
T.MAX_CHARS = 300      -- longest question or description a player may send

--- Number of characters (UTF-8 code points) in s.
function T.char_count(s)
	local _, n = s:gsub("[^\128-\191]", "")
	return n
end

--- nil if the text may be sent, otherwise a message for the player.
function T.check_length(text)
	if T.char_count(text) > T.MAX_CHARS then
		return "That is too long for the tutor. Please keep it under " .. T.MAX_CHARS .. " characters."
	end
	return nil
end

--- cooldown: seconds between requests from one player (default T.COOLDOWN).
function T.new_limiter(cooldown)
	return { last = {}, busy = {}, in_flight = 0, cooldown = cooldown }
end

--- Reserves a request slot for a player. now is in seconds.
-- Returns true, or false and a friendly message.
function T.try_start(lim, name, now)
	if lim.busy[name] then
		return false, "The tutor is still thinking about your last question."
	end
	local last = lim.last[name]
	local cooldown = lim.cooldown or T.COOLDOWN
	if last and now - last < cooldown then
		local wait = math.ceil(cooldown - (now - last))
		return false, "Give the tutor a moment: you can ask again in " .. wait .. " s."
	end
	if lim.in_flight >= T.MAX_IN_FLIGHT then
		return false, "The tutor is helping other players right now. Try again in a few seconds."
	end
	lim.busy[name] = true
	lim.last[name] = now
	lim.in_flight = lim.in_flight + 1
	return true
end

--- Releases the slot taken by try_start once the reply (or error) has arrived.
function T.finish(lim, name)
	if lim.busy[name] then
		lim.busy[name] = nil
		lim.in_flight = lim.in_flight - 1
	end
end

local INTRO = "You are the tutor inside crystalminer, a Luanti world where students learn symmetry, the "
	.. "foundation of crystallography. Each region of the world has a symmetry group: whatever a "
	.. "student builds there is copied by every operation of the group."
local RULE_TIER = "- Pitch the answer at the student's tier. Ideas from a higher tier than theirs can be mentioned "
	.. "as something they will meet later, without explaining them in full."
local RULE_QUIZ = "- Do not give away quiz answers or the hidden symmetry of the Mystery Lab. Give a hint about what "
	.. "to build or look for instead."
local RULE_TOPIC = "- If the question is not about symmetry, crystals or this world, say briefly that you can only "
	.. "help with those."

--- The reviewed lesson text both prompts answer from, appended to lines.
local function add_reference(lines)
	lines[#lines + 1] = "REFERENCE"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Glossary:"
	for _, g in ipairs(content.glossary) do lines[#lines + 1] = "- " .. g end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Introduction (tier 0):"
	for _, l in ipairs(content.intro) do lines[#lines + 1] = "- " .. l end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Museum navigation:"
	lines[#lines + 1] = "- The foyer is the starting area and contains the welcome board."
	lines[#lines + 1] = "- Visitor information is east of the foyer and contains the information desk."
	lines[#lines + 1] = "- The Workshop is west of the foyer and contains the Try-it Pad."
	lines[#lines + 1] = "- Gallery 1 is north of the foyer and teaches translation, rotation, reflection and inversion."
	lines[#lines + 1] = "- Beyond Gallery 1 are Gallery 2, the history of crystallography, and Gallery 3, crystals at the atomic scale."
	lines[#lines + 1] = "- The Portal Hall is furthest north and contains a portal to each symmetry world."
	lines[#lines + 1] = "- The /quiz command unlocks tiers; /tour starts a guided tour; /guide lists commands; /spawn returns to the foyer."
	for _, a in ipairs(content.regions) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Region: " .. a.name .. " (tier " .. a.tier .. ", symmetry "
			.. (a.hidden and "hidden" or a.symbol) .. ")"
		local tiers = {}
		for t in pairs(a.explain or {}) do tiers[#tiers + 1] = t end
		table.sort(tiers)
		for _, t in ipairs(tiers) do
			lines[#lines + 1] = "  Tier " .. t .. ":"
			for _, l in ipairs(a.explain[t]) do lines[#lines + 1] = "  - " .. l end
		end
	end
	return lines
end

function T.tutor_system_prompt()
	local lines = {
		INTRO,
		"",
		"How to answer:",
		"- Use only the reference below. If it does not cover the question, say you are not sure and "
			.. "suggest asking their teacher. Never guess or invent facts.",
		"- Reply in plain text for game chat: no markdown, no bullet symbols, at most 80 words.",
		RULE_TIER,
		RULE_QUIZ,
		RULE_TOPIC,
		"",
	}
	return table.concat(add_reference(lines), "\n")
end

--- System prompt for the chat window (tutor_window.lua): a conversation with Prism, the tutor at the museum's information desk. The same grounding rules as /ask, a little more room to explain, and the museum's galleries (history, crystal structures) in the reference as well.
function T.chat_system_prompt()
	local name = content.tutor and content.tutor.name or "the tutor"
	local lines = {
		INTRO,
		"",
		"You are " .. name .. ", a friendly crystal who answers students' questions at the information "
			.. "desk of the Museum of Crystals and Symmetry. This is a conversation: earlier messages are "
			.. "the same student's, so build on them.",
		"",
		"How to answer:",
		"- Use only the reference below. If it does not cover the question, say you are not sure and "
			.. "suggest asking their teacher. Never guess or invent facts.",
		"- Plain text, at most 120 words. You may use **bold** for a key word; no other markdown, no "
			.. "headings, no tables. Short paragraphs.",
		"- Explain with things the student can do or see in the game when you can: a world to visit, "
			.. "something to build, a command such as /step or /whatsymmetry.",
		RULE_TIER,
		RULE_QUIZ,
		RULE_TOPIC,
		"",
	}
	add_reference(lines)
	local m = content.museum
	if m then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Gallery 3, " .. m.name .. ":"
		for _, l in ipairs(m.intro or {}) do lines[#lines + 1] = "- " .. l end
		for _, e in ipairs(m.exhibits or {}) do
			lines[#lines + 1] = "  " .. (e.label or e.name) .. ":"
			for _, f in ipairs(e.facts or {}) do lines[#lines + 1] = "  - " .. f end
		end
	end
	local history = content.lobby and content.lobby.history
	if history then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Gallery 2, a history of crystallography:"
		for _, h in ipairs(history) do lines[#lines + 1] = "- " .. h.year .. ", " .. h.who .. ": " .. h.text end
	end
	return table.concat(lines, "\n")
end

function T.symmetry_system_prompt()
	local symbols = {}
	for _, e in ipairs(S.catalog) do symbols[#symbols + 1] = e.symbol end
	return "A student describes a symmetry in words. Pick the crystallographic point group that matches "
		.. "the description. Use exactly one symbol from this list, or 'none' if nothing matches (for "
		.. "example a 5-fold axis, which no crystal can have):\n"
		.. table.concat(symbols, " ") .. " \n\n"
		.. "If the description is incomplete, choose the smallest group that has everything mentioned. "
		.. "For example \"a fourfold axis\" is 4, \"a fourfold axis with mirrors\" is 4mm, \"a mirror\" is m. "
		.. "Pick the group even if it cannot be built on a grid of cubes; the game checks that separately."
end

local function base(system, user_text)
	return {
		model = T.MODEL,
		max_tokens = T.MAX_TOKENS,
		-- https://platform.claude.com/docs/en/build-with-claude/effort (GA, no beta header)
		output_config = { effort = "low" },
		-- Server-side fallback (beta, needs the anthropic-beta header in T.headers): if a safety
		-- classifier declines, the API retries on a recommended fallback model.
		-- https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback#server-side-fallback
		fallbacks = "default",
		system = { { type = "text", text = system, cache_control = { type = "ephemeral" } } },
		messages = { { role = "user", content = user_text } },
	}
end

function T.ask_body(question, tier, region_name)
	return base(T.tutor_system_prompt(),
		"Student tier: " .. tier .. "\nStudent is in: " .. (region_name or "no region") .. "\nQuestion: " .. question)
end

function T.symmetry_body(description)
	local body = base(T.symmetry_system_prompt(), "Description: " .. description)
	-- Structured outputs, GA, no beta header:
	-- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
	-- The field is "explanation", not "reason": the docs warn that a property asking for the
	-- model's reasoning can trigger a reasoning_extraction refusal; a short explanation is fine.
	body.output_config.format = {
		type = "json_schema",
		schema = {
			type = "object",
			properties = {
				symbol = {
					type = "string",
					description = "Hermann-Mauguin symbol of the crystallographic point group that matches the "
						.. "description, exactly as written in the list, or 'none' if no point group matches",
				},
				explanation = {
					type = "string",
					description = "One short sentence for a student explaining which words in the description "
						.. "led to this symbol. Do not list the group's operations.",
				},
			},
			required = { "symbol", "explanation" },
			additionalProperties = false,
		},
	}
	return body
end

function T.headers(api_key)
	return {
		"Content-Type: application/json",
		"x-api-key: " .. api_key,
		"anthropic-version: 2023-06-01",
		-- Required for the fallbacks field; must be exactly this date for fallbacks = "default".
		"anthropic-beta: server-side-fallback-2026-07-01",
	}
end

--- Text of a Messages API response, or nil and a message for the player.
function T.response_text(response)
	if type(response) ~= "table" then return nil, "The tutor sent an unreadable reply." end
	if response.type == "error" then
		local kind = response.error and response.error.type or "error"
		if kind == "rate_limit_error" or kind == "overloaded_error" then
			return nil, "The tutor is busy right now. Try again in a minute."
		end
		return nil, "The tutor is unavailable (" .. kind .. ")."
	end
	if response.stop_reason == "refusal" then
		return nil, "The tutor can't answer that one. Try asking about symmetry or crystals."
	end
	-- A cut-off reply may be half a sentence or broken JSON, so it is not shown.
	-- https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons
	if response.stop_reason == "max_tokens" or response.stop_reason == "model_context_window_exceeded" then
		return nil, "The tutor's answer was cut off. Try a shorter or simpler question."
	end
	local parts = {}
	for _, block in ipairs(response.content or {}) do
		if block.type == "text" then parts[#parts + 1] = block.text end
	end
	local text = table.concat(parts):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil, "The tutor had nothing to say. Try rephrasing your question." end
	return text
end

--- Sends a request. http is Luanti's HTTP API; encode/decode are core.write_json/parse_json.
-- cfg is a table from T.config (a plain string is taken as an Anthropic API key).
-- callback(text_or_nil, error_message_or_nil)
function T.send(http, cfg, body, encode, decode, callback)
	if type(cfg) == "string" then cfg = { provider = "anthropic", api_key = cfg } end
	if cfg.provider == "openai_compatible" then
		T.openai_fetch(http, cfg, body, encode, decode, function(text, err) callback(text, err) end)
		return
	end
	local api_key = cfg.api_key
	local ok, data = pcall(encode, body)
	if not ok or type(data) ~= "string" then
		callback(nil, "The tutor could not send that question.")
		return
	end
	http.fetch({
		url = T.URL,
		method = "POST",
		extra_headers = T.headers(api_key),
		data = data,
		timeout = 90,
	}, function(res)
		if not res.succeeded then
			callback(nil, "The tutor could not be reached.")
			return
		end
		local ok, parsed = pcall(decode, res.data)
		if not ok or parsed == nil then
			callback(nil, "The tutor sent an unreadable reply.")
			return
		end
		callback(T.response_text(parsed))
	end)
end

---------------------------------------------------------------------------------------------------
-- Providers. "anthropic" (the default) is the Messages API above, unchanged. "openai_compatible" is
-- the Chat Completions API defined by OpenAI and also served by local servers such as Ollama and
-- llama.cpp's llama-server, so free open-source models can run the tutor:
--   https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create
--   https://docs.ollama.com/api/openai-compatibility
--   https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
-- Both providers get the same system prompts (tutor_system_prompt, symmetry_system_prompt), so the
-- grounding rules are the same.

T.DEFAULT_BASE_URL = "http://localhost:11434/v1" -- Ollama's OpenAI-compatible endpoint

-- The model is chosen the way LiteLLM names models, "provider/model" (https://docs.litellm.ai/docs/providers), with each provider's key in the environment variable LiteLLM reads. Luanti runs only Lua, so the game cannot call LiteLLM itself: it speaks the Messages API to Anthropic and the Chat Completions API to everyone else. Any other model LiteLLM supports (Bedrock, Vertex AI, Azure, Cohere, ...) is reached through a LiteLLM proxy server, "litellm_proxy/<model name on the proxy>".
-- name: shown to players ("Powered by ..."); base: the API address up to /chat/completions; env: the key's environment variable; env_base: one that replaces base; v1: base must end in /v1 (added to an env_base without it); keyless: runs without a key (local servers); model: the default model when only the provider is given.
-- DeepSeek was checked against its API in October 2026 (GET /models lists deepseek-flash and deepseek-v4-pro); the other addresses are those the providers document for their OpenAI-compatible APIs.
T.PROVIDERS = {
	deepseek = { name = "DeepSeek", base = "https://api.deepseek.com", env = "DEEPSEEK_API_KEY", env_base = "DEEPSEEK_API_BASE", model = "deepseek-flash" },
	anthropic = { name = "Claude", anthropic = true, env = "ANTHROPIC_API_KEY", model = T.MODEL },
	openai = { name = "OpenAI", base = "https://api.openai.com/v1", env = "OPENAI_API_KEY", env_base = "OPENAI_API_BASE" },
	gemini = { name = "Google Gemini", base = "https://generativelanguage.googleapis.com/v1beta/openai", env = "GEMINI_API_KEY" },
	groq = { name = "Groq", base = "https://api.groq.com/openai/v1", env = "GROQ_API_KEY" },
	mistral = { name = "Mistral", base = "https://api.mistral.ai/v1", env = "MISTRAL_API_KEY" },
	openrouter = { name = "OpenRouter", base = "https://openrouter.ai/api/v1", env = "OPENROUTER_API_KEY" },
	together_ai = { name = "Together AI", base = "https://api.together.xyz/v1", env = "TOGETHERAI_API_KEY" },
	xai = { name = "xAI", base = "https://api.x.ai/v1", env = "XAI_API_KEY" },
	fireworks_ai = { name = "Fireworks AI", base = "https://api.fireworks.ai/inference/v1", env = "FIREWORKS_AI_API_KEY" },
	perplexity = { name = "Perplexity", base = "https://api.perplexity.ai", env = "PERPLEXITYAI_API_KEY" },
	cerebras = { name = "Cerebras", base = "https://api.cerebras.ai/v1", env = "CEREBRAS_API_KEY" },
	ollama = { name = "Ollama", base = T.DEFAULT_BASE_URL, env_base = "OLLAMA_API_BASE", v1 = true, keyless = true },
	lm_studio = { name = "LM Studio", base = "http://localhost:1234/v1", env = "LM_STUDIO_API_KEY", env_base = "LM_STUDIO_API_BASE", v1 = true, keyless = true },
	hosted_vllm = { name = "vLLM", env = "HOSTED_VLLM_API_KEY", env_base = "HOSTED_VLLM_API_BASE", v1 = true, keyless = true },
	litellm_proxy = { name = "a LiteLLM proxy", base = "http://localhost:4000/v1", env = "LITELLM_PROXY_API_KEY", env_base = "LITELLM_PROXY_API_BASE", v1 = true, keyless = true },
}
T.PROVIDERS.ollama_chat = T.PROVIDERS.ollama   -- LiteLLM's other name for Ollama
T.DEFAULT_MODEL = "deepseek/deepseek-flash"

--- The provider names, sorted, for messages.
function T.provider_names()
	local list = {}
	for k in pairs(T.PROVIDERS) do list[#list + 1] = k end
	table.sort(list)
	return table.concat(list, ", ")
end

T.ANTHROPIC_TIMEOUT = 90
T.OPENAI_TIMEOUT = 60          -- seconds; crystalminer.tutor_timeout changes it
T.OPENAI_TEMPERATURE = 0.2
-- Small local models are slow on a CPU, so their answers are kept short. Thinking models need more:
-- crystalminer.tutor_max_tokens sets both.
T.OPENAI_ASK_TOKENS = 400
T.OPENAI_SYMMETRY_TOKENS = 200
-- Not every OpenAI-compatible server accepts "json_schema" (llama-cpp-python rejects it), so
-- /symmetry falls back to "json_object" and then to no response_format; the prompt asks for JSON.
T.RESPONSE_FORMATS = { "json_schema", "json_object", "none" }
T.SYMMETRY_JSON_INSTRUCTION = "\n\nReply with only a JSON object with two string fields, "
	.. "\"symbol\" (one symbol from the list, or \"none\") and \"explanation\" (one short sentence for "
	.. "the student). No other text."

local function trim(s)
	if type(s) ~= "string" then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Settings for the Messages API (Claude). model: the model's name, without "anthropic/".
local function anthropic_config(get, getenv, model)
	local key = get("crystalminer.anthropic_api_key")
	if not key or key == "" then key = get("crystalminer.tutor_api_key") end
	if not key or key == "" then key = getenv("ANTHROPIC_API_KEY") end
	local cfg = { provider = "anthropic", prefix = "anthropic", service = T.PROVIDERS.anthropic.name, url = T.URL,
		model = model ~= "" and model or T.MODEL, api_key = key, timeout = T.ANTHROPIC_TIMEOUT }
	if key == nil or key == "" then return cfg, "no API key set" end
	return cfg
end

--- Settings for the Chat Completions API. p: an entry of T.PROVIDERS, or nil for a server given only by crystalminer.tutor_base_url (provider openai_compatible).
local function openai_config(get, getenv, p, prefix, model)
	local base = trim(get("crystalminer.tutor_base_url"))
	-- The setting's default in the main menu is Ollama's address; it stands only for Ollama or for openai_compatible.
	if base == T.DEFAULT_BASE_URL and p and p.base ~= T.DEFAULT_BASE_URL then base = "" end
	if base == "" and p and p.env_base then
		base = trim(getenv(p.env_base))
		if base ~= "" and p.v1 and not base:gsub("/+$", ""):match("/v1$") then base = base:gsub("/+$", "") .. "/v1" end
	end
	-- A provider without a usual address (vLLM) gets none, so the setting is asked for; a bare openai_compatible gets Ollama's.
	if base == "" then
		if p then base = p.base or "" else base = T.DEFAULT_BASE_URL end
	end
	base = base:gsub("/+$", "")
	local key = trim(get("crystalminer.tutor_api_key"))
	if key == "" and p and p.env then key = trim(getenv(p.env)) end
	if key == "" then key = trim(getenv("CRYSTALMINER_TUTOR_API_KEY")) end
	local timeout = math.floor(tonumber(get("crystalminer.tutor_timeout")) or T.OPENAI_TIMEOUT)
	local max_tokens = tonumber(get("crystalminer.tutor_max_tokens"))
	if max_tokens then max_tokens = math.max(16, math.min(T.MAX_TOKENS, math.floor(max_tokens))) end
	if model == "" and p and p.model then model = p.model end
	local cfg = {
		provider = "openai_compatible",
		prefix = prefix,
		service = p and p.name or nil,
		base_url = base,
		url = base .. "/chat/completions",
		model = model,
		api_key = key ~= "" and key or nil,
		timeout = math.max(5, math.min(600, timeout)),
		ask_tokens = max_tokens or T.OPENAI_ASK_TOKENS,
		symmetry_tokens = max_tokens or T.OPENAI_SYMMETRY_TOKENS,
	}
	if base == "" then
		return cfg, "set crystalminer.tutor_base_url (or " .. (p and p.env_base or "the base URL") .. ") to the address of the " .. (p and p.name or "") .. " server"
	end
	if not base:match("^https?://[^%s]+$") then
		return cfg, "crystalminer.tutor_base_url must start with http:// or https://"
	end
	if cfg.model == "" then return cfg, "set crystalminer.tutor_model to the name of the model" end
	if p and not p.keyless and key == "" then
		return cfg, "no " .. p.name .. " API key set (" .. p.env .. " or crystalminer.tutor_api_key)"
	end
	if key:find("%c") then return cfg, "the tutor API key contains control characters" end
	return cfg
end

--- Reads the tutor settings. get(name) returns a setting or nil; getenv is os.getenv.
-- The model is crystalminer.tutor_model, else the environment variable CRYSTALMINER_TUTOR_MODEL, else T.DEFAULT_MODEL: "provider/model" with a provider of T.PROVIDERS. crystalminer.tutor_provider can name the provider instead (then the model has no prefix); "openai_compatible" there means any server at crystalminer.tutor_base_url, with the model's name taken as it is, slashes and all.
-- Returns cfg when the tutor can run; otherwise cfg (or nil) and the reason it is off.
function T.config(get, getenv)
	local provider = trim(get("crystalminer.tutor_provider")):lower()
	if provider == "auto" then provider = "" end
	local spec = trim(get("crystalminer.tutor_model"))
	if spec == "" then spec = trim(getenv("CRYSTALMINER_TUTOR_MODEL")) end
	if provider == "openai_compatible" then return openai_config(get, getenv, nil, "openai_compatible", spec) end
	-- A provider in front of the model wins over the provider setting.
	local prefix, model = spec:match("^([%w_]+)/(.+)$")
	if prefix and T.PROVIDERS[prefix:lower()] then
		provider = prefix:lower()
	elseif provider ~= "" then
		model = spec
	elseif spec == "" then
		provider, model = T.DEFAULT_MODEL:match("^([%w_]+)/(.+)$")
	else
		return nil, "crystalminer.tutor_model '" .. spec .. "' needs a provider in front, as in deepseek/deepseek-flash or ollama/llama3.2 (providers: " .. T.provider_names() .. ")"
	end
	local p = T.PROVIDERS[provider]
	if not p then
		return nil, "unknown crystalminer.tutor_provider '" .. provider .. "' (use openai_compatible or one of: " .. T.provider_names() .. ")"
	end
	model = trim(model)
	if p.anthropic then return anthropic_config(get, getenv, model) end
	return openai_config(get, getenv, p, provider, model)
end

--- One line for the server log. Never includes the API key.
function T.describe(cfg)
	if cfg.provider == "anthropic" then
		return "provider anthropic, url " .. cfg.url .. ", model " .. cfg.model
	end
	local url = cfg.base_url:gsub("//[^/@]*@", "//***@")
	local name = cfg.prefix and cfg.prefix ~= "openai_compatible" and (cfg.prefix .. " (openai_compatible)") or "openai_compatible"
	return "provider " .. name .. ", base_url " .. url .. ", model "
		.. (cfg.model ~= "" and cfg.model or "(not set)") .. ", API key " .. (cfg.api_key and "set" or "not set")
end

function T.openai_headers(api_key)
	local h = { "Content-Type: application/json" }
	if api_key and api_key ~= "" then h[#h + 1] = "Authorization: Bearer " .. api_key end
	return h
end

local function openai_body(cfg, system, user_text, max_tokens)
	return {
		model = cfg.model,
		messages = { { role = "system", content = system }, { role = "user", content = user_text } },
		max_tokens = max_tokens,
		temperature = T.OPENAI_TEMPERATURE,
	}
end

--- Request body for /ask with the configured provider. The text is the same for both providers.
function T.ask_request(cfg, question, tier, region_name)
	local a = T.ask_body(question, tier, region_name)
	if cfg.provider ~= "openai_compatible" then
		a.model = cfg.model or T.MODEL
		return a
	end
	return openai_body(cfg, a.system[1].text, a.messages[1].content, cfg.ask_tokens)
end

T.CHAT_HISTORY = 12   -- earlier messages (user and tutor) sent with each chat question
T.CHAT_TOKENS = 1500  -- chat answers with an OpenAI-compatible model: room for a thinking model

--- Request body for one question in the chat window. history: earlier messages of this conversation, oldest first, { role = "user" | "assistant" | anything else, text = ... }. Only questions that were answered are sent, each with its answer, so turns alternate; at most the last T.CHAT_HISTORY messages.
function T.chat_request(cfg, history, question, tier, place)
	local pairs_ = {}
	history = history or {}
	for i = 1, #history - 1 do
		local q, a = history[i], history[i + 1]
		if q.role == "user" and a.role == "assistant" then
			pairs_[#pairs_ + 1] = { role = "user", content = q.text }
			pairs_[#pairs_ + 1] = { role = "assistant", content = a.text }
		end
	end
	local msgs = {}
	for i = math.max(1, #pairs_ - T.CHAT_HISTORY + 1), #pairs_ do msgs[#msgs + 1] = pairs_[i] end
	msgs[#msgs + 1] = { role = "user", content = "Student tier: " .. tier .. "\nStudent is in: "
		.. (place or "the museum") .. "\nQuestion: " .. question }
	local system = T.chat_system_prompt()
	if cfg.provider ~= "openai_compatible" then
		local b = base(system, "")
		b.model, b.messages = cfg.model or T.MODEL, msgs
		return b
	end
	table.insert(msgs, 1, { role = "system", content = system })
	return { model = cfg.model, messages = msgs, max_tokens = math.max(cfg.ask_tokens or 0, T.CHAT_TOKENS),
		temperature = T.OPENAI_TEMPERATURE }
end

--- Request body for /symmetry. mode (openai_compatible only) is one of T.RESPONSE_FORMATS.
function T.symmetry_request(cfg, description, mode)
	local a = T.symmetry_body(description)
	if cfg.provider ~= "openai_compatible" then
		a.model = cfg.model or T.MODEL
		return a
	end
	local body = openai_body(cfg, a.system[1].text .. T.SYMMETRY_JSON_INSTRUCTION, a.messages[1].content,
		cfg.symmetry_tokens)
	mode = mode or "json_schema"
	if mode == "json_schema" then
		body.response_format = { type = "json_schema", json_schema = {
			name = "point_group_choice", schema = a.output_config.format.schema, strict = true } }
	elseif mode == "json_object" then
		body.response_format = { type = "json_object" }
	end
	return body
end

function T.http_error_message(code)
	code = tonumber(code) or 0
	if code == 429 then return "The tutor is busy right now. Try again in a minute." end
	if code == 401 or code == 403 then return "The tutor is unavailable: the AI server refused the API key." end
	if code == 404 then return "The tutor is unavailable: the AI server does not know that model or address." end
	if code >= 400 then return "The tutor is unavailable (error " .. code .. ")." end
	return "The tutor is unavailable."
end

local function error_detail(response)
	local err = response and response.error
	local message = type(err) == "table" and err.message or nil
	if type(message) ~= "string" or message == "" then return nil end
	return message:gsub("[%c\r\n]", " "):sub(1, 240)
end

--- Text of a Chat Completions response, or nil and a message for the player. code is the HTTP status.
function T.openai_response_text(response, code)
	if type(response) ~= "table" then return nil, "The tutor sent an unreadable reply." end
	code = tonumber(code) or 200
	if response.error ~= nil or code >= 400 then
		local detail = error_detail(response)
		return nil, T.http_error_message(code) .. (detail and ": " .. detail or "")
	end
	local choice = type(response.choices) == "table" and response.choices[1]
	if type(choice) ~= "table" then return nil, "The tutor sent an unreadable reply." end
	-- A cut-off reply may be half a sentence or broken JSON, so it is not shown.
	if choice.finish_reason == "length" then
		return nil, "The tutor's answer was cut off. Try a shorter or simpler question."
	end
	if choice.finish_reason == "content_filter" then
		return nil, "The tutor can't answer that one. Try asking about symmetry or crystals."
	end
	local msg = type(choice.message) == "table" and choice.message or {}
	local content = msg.content
	if type(content) == "table" then
		local parts = {}
		for _, p in ipairs(content) do
			if type(p) == "table" and type(p.text) == "string" then parts[#parts + 1] = p.text end
		end
		content = table.concat(parts)
	end
	if type(content) ~= "string" then content = "" end
	-- Some local reasoning models put their thinking in the reply; it is never shown.
	content = content:gsub("^%s*<think>.-</think>", "")
	if content:match("^%s*<think>") then content = "" end
	content = trim(content)
	if content == "" then
		if type(msg.refusal) == "string" and msg.refusal ~= "" then
			return nil, "The tutor can't answer that one. Try asking about symmetry or crystals."
		end
		return nil, "The tutor had nothing to say. Try rephrasing your question."
	end
	return content
end

--- One Chat Completions request. done(text, err, retryable): retryable is true when the server
-- returned an HTTP error that another response_format might avoid.
function T.openai_fetch(http, cfg, body, encode, decode, done)
	local ok, data = pcall(encode, body)
	if not ok or type(data) ~= "string" then
		done(nil, "The tutor could not send that question.")
		return
	end
	http.fetch({
		url = cfg.url,
		method = "POST",
		extra_headers = T.openai_headers(cfg.api_key),
		data = data,
		timeout = cfg.timeout or T.OPENAI_TIMEOUT,
	}, function(res)
		if not res.succeeded then
			done(nil, res.timeout and "The tutor took too long to answer. Try again with a simpler question."
				or "The tutor could not be reached.")
			return
		end
		local code = tonumber(res.code) or 0
		local retryable = code >= 400 and code ~= 401 and code ~= 403 and code ~= 404 and code ~= 429
		local okd, parsed = pcall(decode, res.data or "", nil, true)
		if not okd or parsed == nil then
			if code >= 400 then
				done(nil, T.http_error_message(code) .. " (the server response was not readable)", retryable)
			else
				done(nil, "The tutor sent an unreadable reply.")
			end
			return
		end
		local text, err = T.openai_response_text(parsed, code)
		done(text, err, text == nil and retryable)
	end)
end

--- /symmetry request. For openai_compatible, an HTTP error is retried once with "json_object" and
-- once more without response_format. The retries happen inside the caller's limiter slot.
function T.send_symmetry(http, cfg, description, encode, decode, callback)
	if cfg.provider ~= "openai_compatible" then
		T.send(http, cfg, T.symmetry_request(cfg, description), encode, decode, callback)
		return
	end
	local function try(i)
		T.openai_fetch(http, cfg, T.symmetry_request(cfg, description, T.RESPONSE_FORMATS[i]), encode, decode,
			function(text, err, retryable)
				if text == nil and retryable and T.RESPONSE_FORMATS[i + 1] then
					try(i + 1)
				else
					callback(text, err)
				end
			end)
	end
	try(1)
end

--- Finds the point-group choice in a model's reply: plain JSON, JSON in ``` fences, or JSON with
-- text around it. Only a symbol the symmetry engine knows (or "none") is accepted.
-- Returns symbol, explanation_or_nil; or nil and a message for the player.
function T.choose_symbol(text, decode)
	local fail = "The tutor could not pick a valid symmetry from that. Try a point-group symbol, like /symmetry 4mm."
	if type(text) ~= "string" then return nil, fail end
	local candidates = { text }
	local fenced = text:match("```[%w_]*%s*(.-)%s*```")
	if fenced then candidates[#candidates + 1] = fenced end
	local braces = text:match("%b{}")
	if braces then candidates[#candidates + 1] = braces end
	for _, c in ipairs(candidates) do
		local ok, obj = pcall(decode, c, nil, true)
		if ok and type(obj) == "table" and type(obj.symbol) == "string" then
			local symbol = trim(obj.symbol)
			if S.point_group(symbol) or symbol:lower() == "none" then
				local note = trim(obj.explanation)
				if note == "" or T.char_count(note) > T.MAX_CHARS then note = nil end
				return symbol, note
			end
		end
	end
	return nil, fail
end

--- Removes a "Tutor:" the model may have written itself, since the game adds its own label.
function T.strip_label(text)
	return (text:gsub("^%s*[Tt]utor%s*:%s*", ""))
end

return T
