local typedefs = require "kong.db.schema.typedefs"

return {
    name = "request-encrypt",
    fields = {
        { protocols = typedefs.protocols_http },
        { config = {
            type = "record",
            fields = {
                { not_encrypt_status = { type = "number", default = 494 } },
                { response_enabled = { type = "boolean", default = true } },
                { redis_host = { type = "string", default = "127.0.0.1" } },
                { redis_port = { type = "number", default = 6379 } },
                { redis_pass = { type = "string" } },
                { redis_database = { type = "number", default = 0 } },
                { signature_timeout = { type = "number", default = 300 } },
                { signature_enabled = { type = "boolean", default = true } },
                { signature_redis_enabled = { type = "boolean", default = false } },
                { request_enabled = { type = "boolean", default = true } },
                { rsa_pri_key = { type = "string" } }
            }
        }
        }
    }
}
