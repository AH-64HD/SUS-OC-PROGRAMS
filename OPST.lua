-- OPST.lua - 批量执行程序 (增强版)
local shell = require("shell")
local fs = require("filesystem")
local event = require("event")

-- 确保term模块正确加载
local term
local ok, err = pcall(function()
    term = require("term")
end)

if not ok then
    print("无法加载term模块: " .. tostring(err))
    return
end

-- 配置：要运行的程序列表
local programsToRun = {
    "/program1.lua",  -- 替换为实际程序路径
    "/program2.lua",  -- 替换为实际程序路径
    "/program3.lua",  -- 替换为实际程序路径
}

-- 显示菜单
function showMenu()
    term.clear()
    term.setCursor(1, 1)
    print("OPST - 批量执行程序")
    print(string.rep("-", 40))
    
    for i, program in ipairs(programsToRun) do
        local exists = fs.exists(program) and "✓" or "✗"
        print(i .. ". " .. exists .. " " .. program)
    end
    
    print(string.rep("-", 40))
    print("1: 执行所有程序")
    print("2: 选择执行程序")
    print("3: 添加程序到列表")
    print("4: 从列表移除程序")
    print("5: 退出")
    print(string.rep("-", 40))
    print("请输入选择:")
end

-- 执行所有程序
function runAllPrograms()
    term.clear()
    term.setCursor(1, 1)
    print("执行所有程序...")
    print(string.rep("-", 40))
    
    for i, program in ipairs(programsToRun) do
        if fs.exists(program) then
            print("执行: " .. program)
            local result = shell.execute(program)
            print("返回代码: " .. tostring(result))
            print("")
        else
            print("程序不存在: " .. program)
            print("")
        end
    end
    
    print("所有程序执行完毕")
    print("输入 'QUIT' 退出程序，或按任意键返回主菜单...")
    
    -- 等待用户输入
    local input = io.read()
    if input and input:upper() == "QUIT" then
        return false -- 退出程序
    end
    
    return true -- 返回主菜单
end

-- 选择执行程序
function selectProgramsToRun()
    term.clear()
    term.setCursor(1, 1)
    print("选择要执行的程序 (输入数字，多个用逗号分隔):")
    print(string.rep("-", 40))
    
    for i, program in ipairs(programsToRun) do
        local exists = fs.exists(program) and "✓" or "✗"
        print(i .. ". " .. exists .. " " .. program)
    end
    
    print(string.rep("-", 40))
    print("请输入选择 (例如: 1,3,5):")
    
    local input = io.read()
    local selections = {}
    
    -- 解析输入
    for num in input:gmatch("%d+") do
        local index = tonumber(num)
        if index and index >= 1 and index <= #programsToRun then
            table.insert(selections, index)
        end
    end
    
    if #selections == 0 then
        print("无效选择")
        os.sleep(1)
        return true
    end
    
    -- 执行选中的程序
    term.clear()
    term.setCursor(1, 1)
    print("执行选中的程序...")
    print(string.rep("-", 40))
    
    for _, index in ipairs(selections) do
        local program = programsToRun[index]
        if fs.exists(program) then
            print("执行: " .. program)
            local result = shell.execute(program)
            print("返回代码: " .. tostring(result))
            print("")
        else
            print("程序不存在: " .. program)
            print("")
        end
    end
    
    print("选中的程序执行完毕")
    print("输入 'QUIT' 退出程序，或按任意键返回主菜单...")
    
    -- 等待用户输入
    local input = io.read()
    if input and input:upper() == "QUIT" then
        return false -- 退出程序
    end
    
    return true -- 返回主菜单
end

-- 添加程序到列表
function addProgram()
    term.clear()
    term.setCursor(1, 1)
    print("添加程序到列表")
    print(string.rep("-", 40))
    print("请输入程序路径:")
    
    local path = io.read()
    if path and path ~= "" then
        table.insert(programsToRun, path)
        print("已添加: " .. path)
    else
        print("无效路径")
    end
    
    os.sleep(1)
    return true -- 返回主菜单
end

-- 从列表移除程序
function removeProgram()
    term.clear()
    term.setCursor(1, 1)
    print("从列表移除程序")
    print(string.rep("-", 40))
    
    for i, program in ipairs(programsToRun) do
        print(i .. ". " .. program)
    end
    
    print(string.rep("-", 40))
    print("请输入要移除的程序编号:")
    
    local input = io.read()
    local index = tonumber(input)
    
    if index and index >= 1 and index <= #programsToRun then
        local removed = table.remove(programsToRun, index)
        print("已移除: " .. removed)
    else
        print("无效选择")
    end
    
    os.sleep(1)
    return true -- 返回主菜单
end

-- 保存配置
function saveConfig()
    local file = io.open("/etc/opst.cfg", "w")
    if file then
        for _, program in ipairs(programsToRun) do
            file:write(program .. "\n")
        end
        file:close()
    end
end

-- 加载配置
function loadConfig()
    if fs.exists("/etc/opst.cfg") then
        programsToRun = {}
        local file = io.open("/etc/opst.cfg", "r")
        if file then
            for line in file:lines() do
                if line and line ~= "" then
                    table.insert(programsToRun, line)
                end
            end
            file:close()
        end
    end
end

-- 主函数
function main()
    loadConfig()
    
    while true do
        showMenu()
        local input = io.read()
        local choice = tonumber(input)
        
        local shouldContinue = true
        
        if choice == 1 then
            shouldContinue = runAllPrograms()
        elseif choice == 2 then
            shouldContinue = selectProgramsToRun()
        elseif choice == 3 then
            addProgram()
            saveConfig()
        elseif choice == 4 then
            removeProgram()
            saveConfig()
        elseif choice == 5 or input:upper() == "QUIT" then
            break
        else
            print("无效选择")
            os.sleep(1)
        end
        
        if not shouldContinue then
            break
        end
    end
    
    term.clear()
    term.setCursor(1, 1)
    print("感谢使用OPST批量执行程序")
end

-- 错误处理
local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursor(1, 1)
    print("程序发生错误: " .. tostring(err))
    print("按任意键退出...")
    event.pull("key")
end