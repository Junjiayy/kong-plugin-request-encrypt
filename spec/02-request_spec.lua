---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by mac.
--- DateTime: 2021/10/3 3:29 下午
---
local helpers = require "spec.helpers"
local rsa = require "resty.rsa"
local json = require "cjson"
local encrypt = require "kong.plugins.request-encrypt.encrypt"
local md5 = require "md5"

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
-- encoding
local function base64_encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- decoding
local function base64_decode(data)
    data = string.gsub(data, '[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end)        :gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

local seeds = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
                "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", }

local function get_random_str(length)
    local random_str = ""
    for i = 1, length do
        random_str = random_str .. seeds[math.random(#seeds)]
    end

    return random_str
end

for _, strategy in helpers.each_strategy() do

    describe("Plugin: request-encrypt", function()
        local file_path = debug.getinfo(1, "S").source:sub(2, -1):match("^.*/")
        local pub_file = assert(io.open(file_path .. "/rsa_test_pub_key.pem", 'r'))
        local pub_content = pub_file:read("*all")
        pub_file:close()

        local pri_file = assert(io.open(file_path .. "/rsa_test_pri_key.pem", 'r'))
        local pri_content = pri_file:read("*all")
        pri_file:close()

        local proxy_client

        lazy_setup(function()
            local bp = helpers.get_db_utils(strategy, { "routes", "services", "plugins", })

            local only_request_en_route = bp.routes:insert({ hosts = { "response.com" }, })
            local sign_and_req_enabled_route = bp.routes:insert({ hosts = { "response2.com" }, })
            local only_response_en_route = bp.routes:insert({ hosts = { "response3.com" }, })
            local all_en_route = bp.routes:insert({ hosts = { "response4.com" }, })
            local sign_use_redis_route = bp.routes:insert({ hosts = { "response5.com" }, })

            bp.plugins:insert {
                route = { id = only_request_en_route.id },
                name = "request-encrypt",
                config = {
                    not_encrypt_status = 494,
                    request_enabled = true,
                    response_enabled = false,
                    rsa_pri_key = pri_content,
                    signature_enabled = false,
                }
            }

            bp.plugins:insert {
                route = { id = sign_use_redis_route.id },
                name = "request-encrypt",
                config = {
                    not_encrypt_status = 494,
                    request_enabled = true,
                    response_enabled = false,
                    rsa_pri_key = pri_content,
                    signature_enabled = true,
                    signature_redis_enabled = true,
                    redis_host = "192.168.56.1",
                    redis_pass = "123456",
                    redis_database = 5,
                }
            }

            bp.plugins:insert {
                route = { id = only_response_en_route.id },
                name = "request-encrypt",
                config = {
                    not_encrypt_status = 494,
                    request_enabled = false,
                    rsa_pri_key = pri_content,
                    signature_enabled = false,
                    response_enabled = true,
                }
            }

            bp.plugins:insert {
                route = { id = all_en_route.id },
                name = "request-encrypt",
                config = {
                    not_encrypt_status = 494,
                    request_enabled = true,
                    rsa_pri_key = pri_content,
                    signature_enabled = true,
                    response_enabled = true,
                    signature_redis_enabled = true,
                    redis_host = "192.168.56.1",
                    redis_pass = "123456",
                    redis_database = 5,
                }
            }

            bp.plugins:insert {
                route = { id = sign_and_req_enabled_route.id },
                name = "request-encrypt",
                config = {
                    not_encrypt_status = 494,
                    request_enabled = true,
                    response_enabled = false,
                    rsa_pri_key = pri_content,
                    signature_enabled = true,
                }
            }

            assert(helpers.start_kong({
                database = strategy,
                nginx_conf = "spec/fixtures/custom_nginx.template",
                plugins = "request-encrypt"
            }))
        end)

        lazy_teardown(function()
            helpers.stop_kong()
        end)

        before_each(function()
            proxy_client = helpers.proxy_client()
        end)

        after_each(function()
            if proxy_client then proxy_client:close() end
        end)

        describe("request spec", function()
            local secret_plaintext = get_random_str(8)
            local pub, _ = rsa:new({ public_key = pub_content })
            local secret, _ = pub:encrypt(secret_plaintext)
            secret = base64_encode(secret)

            it("send a request with only request encrypt", function()
                local request_body = { path = "/api-get", method = "get", query = "name=a&age=18" }
                --print(encrypt.encode(secret_plaintext, json.encode(request_body)))
                --local timestamp = os.time()
                --local nonce_str = get_random_str(16)

                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = encrypt.encode(secret_plaintext, json.encode(request_body)),
                    headers = {
                        host = "response.com",
                        secret = secret,
                        ["Content-Type"] = "application/json"
                    }
                })

                assert.response(res).status(200)
                local resp = assert.response(res).has.jsonbody()
                assert.equal(resp.query, request_body.query)
                assert.equal(resp.method, request_body.method:upper())
            end)

            it("request parameters verify", function()
                local request_body = { path = "/api-post" }

                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = encrypt.encode(secret_plaintext, json.encode(request_body)),
                    headers = {
                        host = "response.com",
                        secret = secret,
                        ["Content-Type"] = "application/json"
                    }
                })

                assert.response(res).status(422)
                --local body = res:read_body()
                --print(body)
            end)

            it("request use signature", function()
                local request_body = { path = "/api-get", method = "get", query = "name=a&age=18" }
                local timestamp = os.time()
                local nonce_str = get_random_str(16)
                local body = encrypt.encode(secret_plaintext, json.encode(request_body))
                local signature = md5.sumhexa(timestamp .. nonce_str .. base64_encode(body) .. secret_plaintext)

                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = body,
                    headers = {
                        host = "response2.com",
                        secret = secret,
                        ["Content-Type"] = "application/json",
                        signature = signature,
                        timestamp = timestamp,
                        ["nonce-str"] = nonce_str
                    }
                })

                assert.response(res).status(200)
                local resp = assert.response(res).has.jsonbody()
                assert.equal(resp.query, request_body.query)
                assert.equal(resp.method, request_body.method:upper())
            end)

            it("request use wrong signature", function()
                local request_body = { path = "/api-get", method = "get", query = "name=a&age=18" }
                local timestamp = os.time()
                local nonce_str = get_random_str(16)
                local body = encrypt.encode(secret_plaintext, json.encode(request_body))
                local signature = md5.sumhexa(timestamp .. nonce_str .. "test" .. secret_plaintext)

                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = body,
                    headers = {
                        host = "response2.com",
                        secret = secret,
                        ["Content-Type"] = "application/json",
                        signature = signature,
                        timestamp = timestamp,
                        ["nonce-str"] = nonce_str
                    }
                })

                assert.response(res).status(494)
            end)

            it("request signature use redis resend the test", function()
                local request_body = { path = "/api-get", method = "get", query = "name=a&age=18" }
                local timestamp = os.time()
                local nonce_str = get_random_str(16)
                local body = encrypt.encode(secret_plaintext, json.encode(request_body))
                local signature = md5.sumhexa(timestamp .. nonce_str .. base64_encode(body) .. secret_plaintext)

                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = body,
                    headers = {
                        host = "response5.com",
                        secret = secret,
                        ["Content-Type"] = "application/json",
                        signature = signature,
                        timestamp = timestamp,
                        ["nonce-str"] = nonce_str
                    }
                })

                assert.response(res).status(200)
                local resp = assert.response(res).has.jsonbody()
                assert.equal(resp.query, request_body.query)
                assert.equal(resp.method, request_body.method:upper())

                local second_res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = body,
                    headers = {
                        host = "response5.com",
                        secret = secret,
                        ["Content-Type"] = "application/json",
                        signature = signature,
                        timestamp = timestamp,
                        ["nonce-str"] = nonce_str
                    }
                })

                assert.response(second_res).status(494)
            end)
        end)

        describe("response spec", function()
            local secret_plaintext = get_random_str(8)
            local pub, _ = rsa:new({ public_key = pub_content })
            local secret, _ = pub:encrypt(secret_plaintext)
            secret = base64_encode(secret)

            it("send a response with only request encrypt", function()
                --local request_body = { path = "/api-get", method = "get", query = "name=a&age=18" }

                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/api-get?name=a&age=18",
                    body = request_body,
                    headers = {
                        host = "response3.com",
                        secret = secret,
                        ["Content-Type"] = "application/json",
                    }
                })

                assert.response(res).status(200)
                local resp_body = res:read_body()
                local plaintext = encrypt.decode(secret_plaintext, resp_body)
                local resp = json.decode(plaintext)
                assert.equal(resp.method, "GET")
                assert.equal(resp.query, "name=a&age=18")
            end)

            it("complete encryption request test", function()
                local request_body = { path = "/api-post", method = "post", query = "name=a&age=18", body = { name = "b", age = 17 } }
                local timestamp = os.time()
                local nonce_str = get_random_str(16)
                --print(json.encode(request_body))
                local body = encrypt.encode(secret_plaintext, json.encode(request_body))
                local signature = md5.sumhexa(timestamp .. nonce_str .. base64_encode(body) .. secret_plaintext)

                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/api",
                    body = body,
                    headers = {
                        host = "response4.com",
                        secret = secret,
                        ["Content-Type"] = "application/json",
                        signature = signature,
                        timestamp = timestamp,
                        ["nonce-str"] = nonce_str
                    }
                })

                assert.response(res).status(200)
                local resp_body = res:read_body()
                local plaintext = encrypt.decode(secret_plaintext, resp_body)
                --print(plaintext)
                local resp = json.decode(plaintext)
                assert.equal(resp.method, request_body.method:upper())
                assert.equal(resp.query, request_body.query)
                assert.equal(resp.body.name, request_body.body.name)
            end)

        end)
    end)
end