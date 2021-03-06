---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by mac.
--- DateTime: 2021/9/30 5:48 下午
---

local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.request-encrypt.access"
local encrypt = require "kong.plugins.request-encrypt.encrypt"
local json = require "cjson"

local kong = kong
local request_encrypt_handler = BasePlugin:extend()

request_encrypt_handler.PRIORITY = 1
request_encrypt_handler.VERSION = '0.1.0'

function request_encrypt_handler:new()
    request_encrypt_handler.super.new(self, "request-encrypt")
end

function request_encrypt_handler:rewrite(conf) kong.service.request.enable_buffering() end

function request_encrypt_handler:access(conf)
    request_encrypt_handler.super.access(self)
    access.execute(conf)
end

function request_encrypt_handler:header_filter(conf)
    request_encrypt_handler.super.header_filter(self)

    -- Clear content-length to facilitate rewriting response body
    -- Modify the content-type to a custom name to convey the meaning that a request is not allowed to view
    kong.response.clear_header("Content-Length")
    kong.response.set_header("Content-Type", "application/kndy; charset=utf-8")
end

function request_encrypt_handler:body_filter(conf)
    request_encrypt_handler.super.body_filter(self)

    if kong.response.get_status() ~= conf.not_encrypt_status and conf.response_enabled
            and kong.request.get_method() ~= "OPTIONS" then

        -- Here we must determine whether the response has been completed,
        -- kong.response.get_raw_body() may get a nil
        local body = kong.response.get_raw_body()
        if body then
            kong.response.set_raw_body(encrypt.encode(kong.ctx.shared.secret, body))
        end
    end
end

return request_encrypt_handler