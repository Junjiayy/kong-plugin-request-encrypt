---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by mac.
--- DateTime: 2021/10/3 2:59 下午
---

describe("Plugin: request-encrypt", function()
    local encrypt = require "kong.plugins.request-encrypt.encrypt"
    local txt, salt = [[{"headers":{"x-forwarded-for":"127.0.0.1","x-forwarded-host":"response3.com","x-forwarded-proto":"http","x-forwarded-path":"\/api-get","connection":"keep-alive","content-type":"application\/json","host":"127.0.0.1:15555","secret":"i2zBmBxM7NVKgYSCEsjXpCNuquz+\/zxUtV\/g4StPkIxSFwouu\/2XlJqBnp9q81wO1\/BZSjHrd42dV5b0\/5AOmfNM5WDXV3g6lTaBNZPXSH1Ak9aZatLewDQ10Y+6mqI+BJIqq2XRq4tq0u6l\/pb10ud5QLnWfxzSHxK7jAj7IeE=","x-forwarded-port":"9000","x-real-ip":"127.0.0.1","user-agent":"lua-resty-http\/0.16.1 (Lua) ngx_lua\/10019"},"query":"name=a&age=18","method":"GET","path":"\/api-get?name=a&age=18"}]], "VZtMHpVW"
    local cipher = encrypt.encode(salt, txt)

    describe("encrypt.decode()", function()
        it("Whether the plaintext after decryption is the same as before encryption", function()
            local plaintext = encrypt.decode(salt, cipher)
            assert.equal(plaintext, txt)
        end)
    end)
end)