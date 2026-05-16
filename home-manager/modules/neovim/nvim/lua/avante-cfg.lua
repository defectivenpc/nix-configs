require("avante_lib").load()
local config = {
	provider = "openai",
	providers = {
		openai = {
			endpoint = "https://api.openai.com/v1",
			model = "gpt-5.1",
			api_key_name = "AVANTE_OPENAI_API_KEY",
		},
	},
}

require("avante").setup(config)
