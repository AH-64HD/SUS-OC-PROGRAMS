-- eventtest.lua
local event = require("event")

print("事件测试 - 按任意键测试 (按Q退出)")

while true do
    local e, address, char, code = event.pull()
    print("事件: " .. tostring(e) .. ", 地址: " .. tostring(address) .. ", 字符: " .. tostring(char) .. ", 代码: " .. tostring(code))
    
    if e == "key_down" and (char == 81 or code == 16) then
        break
    end
end