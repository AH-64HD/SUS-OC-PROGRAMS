-- monitor.lua - 简化版监控器程序
local event = require("event")
local shell = require("shell")
local fs = require("filesystem")

-- 全局变量
monitor = {}
monitor.lastPath = shell.getWorkingDirectory()
monitor.isMonitoring = true
monitor.lastProgram = nil

-- 替代getRunningProgram的方法
function monitor.getCurrentProgram()
    -- 使用进程信息或其他方法获取当前程序
    local process = require("process")
    local info = process.info()
    return info and info.data and info.data.path or nil
end

-- 显示启动菜单
function monitor.showStartMenu()
    term.clear()
    term.setCursor(1, 1)
    print("JHJM 监控器程序")
    print(string.rep("-", 40))
    print("请选择操作:")
    print("1: 启动JHJM")
    print("2: 返回主界面")
    print("")
    print("请输入选择 (1 或 2):")
end

-- 处理启动选项
function monitor.handleStartOption()
    monitor.showStartMenu()
    
    -- 监听用户输入
    while true do
        local eventData = {event.pull()}
        
        if eventData[1] == "key_down" then
            local keyCode = eventData[3]
            
            -- 处理数字键输入
            if keyCode == 2 then  -- 数字键1
                print("启动JHJM...")
                shell.execute("/jhjm.lua")
                return true
            elseif keyCode == 3 then  -- 数字键2
                print("返回主界面...")
                return false
            end
        elseif eventData[1] == "terminate" then
            monitor.isMonitoring = false
            return false
        end
    end
end

-- 监听程序退出事件
function monitor.startMonitoring()
    print("启动程序退出监听器...")
    print("监控中，程序将在后台运行")
    print("----------------------------")
    
    -- 保存当前运行程序
    monitor.lastProgram = monitor.getCurrentProgram()
    
    while monitor.isMonitoring do
        -- 监听事件，包括terminate事件
        local eventData = {event.pull(1)}  -- 1秒超时，避免占用太多资源
        
        if eventData[1] == "terminate" then
            monitor.isMonitoring = false
            break
        end
        
        -- 检查当前运行程序
        local currentProgram = monitor.getCurrentProgram()
        
        -- 检测程序退出
        if monitor.lastProgram and not currentProgram then
            -- 程序已退出，显示启动菜单
            print("检测到程序退出，显示启动选项...")
            if not monitor.handleStartOption() then
                monitor.isMonitoring = false
                break
            end
        end
        
        monitor.lastProgram = currentProgram
    end
    
    print("监控程序已退出")
end

-- 主函数
function main()
    -- 显示启动菜单
    if not monitor.handleStartOption() then
        return
    end
    
    -- 启动监控
    monitor.startMonitoring()
end

-- 错误处理
local ok, err = pcall(main)
if not ok then
    print("监控程序错误: " .. tostring(err))
end