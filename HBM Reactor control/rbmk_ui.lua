-- RBMK反应堆监控系统 - 增强版
-- 基于colors.lua的视觉风格，包含菜单系统和自动安全功能

-- 引入组件库
local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")
local os = require("os")
local keyboard = require("keyboard")

-- 配置参数
local SCREEN_WIDTH, SCREEN_HEIGHT = 160, 50  -- 加宽界面

-- 全局变量
local reactor_console
local gpu = component.gpu
local last_component_data = {}  -- 存储上一次的组件数据
local last_redraw_time = 0      -- 上次重绘时间
local selected_x, selected_y = 7, 7  -- 默认选中位置
local status_message = ""       -- 状态消息
local message_time = 0          -- 消息显示时间
local settings = {
    max_temperature = 2500,     -- 默认最高温度
    control_rod_level = 0.5,    -- 默认控制棒水平
    auto_emergency = true,      -- 自动紧急停堆
    xenon_threshold = 0.8,      -- 氙中毒阈值
    temperature_threshold = 0.9 -- 温度阈值百分比
}
local current_screen = "menu"   -- 当前屏幕: menu, monitor, settings
local menu_selection = 1        -- 菜单选择项
local input_mode = false        -- 输入模式
local input_buffer = ""         -- 输入缓冲区
local input_prompt = ""         -- 输入提示
local input_default = ""        -- 输入默认值

-- 初始化函数
function init()
    -- 获取所有组件
    local components = component.list()
    
    -- 查找反应堆控制台
    for address, name in components do
        if name == "rbmk_console" then
            reactor_console = component.proxy(address)
            print("找到反应堆控制台: " .. address)
            break
        end
    end
    
    if not reactor_console then
        print("错误: 未找到反应堆控制台!")
        return false
    end
    
    -- 设置GPU分辨率
    gpu.setResolution(SCREEN_WIDTH, SCREEN_HEIGHT)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, SCREEN_WIDTH, SCREEN_HEIGHT, " ")
    
    -- 初始化组件数据存储
    for x = 0, 14 do
        last_component_data[x] = {}
        for y = 0, 14 do
            last_component_data[x][y] = {}
        end
    end
    
    -- 初始化完成
    print("RBMK监控系统初始化完成")
    return true
end

-- 绘制控制棒位置 (基于colors.lua)
local function draw_control_pos(x, y, degree)
    local start_x = 5 + 8 * x  -- 加宽网格
    local start_y = 3 + 3 * y
    
    if degree < 0.2 then
        gpu.setBackground(0x00FFFF)
        gpu.fill(start_x, start_y, 8, 3, "▌")
    elseif degree >= 0.2 and degree < 0.4 then
        gpu.setBackground(0x00B6FF)
        gpu.fill(start_x, start_y, 8, 3, "▌")
    elseif degree >= 0.4 and degree < 0.6 then
        gpu.setBackground(0x006DFF)
        gpu.fill(start_x, start_y, 8, 3, "▌")
    elseif degree >= 0.6 and degree < 0.8 then
        gpu.setBackground(0x0024FF)
        gpu.fill(start_x, start_y, 8, 3, "▌")
    elseif degree >= 0.8 then
        gpu.setBackground(0x0000FF)
        gpu.fill(start_x, start_y, 8, 3, "▌")
    end
end

-- 绘制燃料棒位置 (基于colors.lua)
local function draw_fuel_pos(x, y, temp, max_temp)
    local start_x = 5 + 8 * x  -- 加宽网格
    local start_y = 3 + 3 * y
    
    -- 根据设置的最高温度计算温度区间
    local temp_5 = max_temp - 500  -- 第五档
    local temp_4 = max_temp - 1000 -- 第四档
    local temp_3 = max_temp - 1500 -- 第三档
    local temp_2 = max_temp - 2000 -- 第二档
    local temp_1 = max_temp - 2500 -- 第一档
    
    if temp < temp_1 then
        gpu.setBackground(0x00FF00)
        gpu.fill(start_x, start_y, 8, 3, " ")
    elseif temp >= temp_1 and temp < temp_2 then
        gpu.setBackground(0xFFB600)
        gpu.fill(start_x, start_y, 8, 3, " ")
    elseif temp >= temp_2 and temp < temp_3 then
        gpu.setBackground(0xFF6D00)
        gpu.fill(start_x, start_y, 8, 3, " ")
    elseif temp >= temp_3 and temp < temp_4 then
        gpu.setBackground(0xFF0000)
        gpu.fill(start_x, start_y, 8, 3, " ")
    elseif temp >= temp_4 and temp < temp_5 then
        gpu.setBackground(0x990000)
        gpu.fill(start_x, start_y, 8, 3, " ")
    elseif temp >= temp_5 then
        gpu.setBackground(0x330000)
        gpu.fill(start_x, start_y, 8, 3, " ")
    end
end

-- 绘制温度标尺 (基于colors.lua)
local function draw_temperature_scale(max_temp)
    local scale_x = 130  -- 调整位置以适应加宽界面
    local scale_y = 5
    
    -- 绘制标题
    gpu.setForeground(0xFFFFFF)
    gpu.set(scale_x, scale_y, "温度标尺 (最高:" .. max_temp .. "°C):")
    
    -- 根据设置的最高温度计算温度区间
    local temp_5 = max_temp - 500  -- 第五档
    local temp_4 = max_temp - 1000 -- 第四档
    local temp_3 = max_temp - 1500 -- 第三档
    local temp_2 = max_temp - 2000 -- 第二档
    local temp_1 = max_temp - 2500 -- 第一档
    
    -- 绘制各个温度级别的示例
    draw_fuel_pos(16, 8, temp_1 - 100, max_temp)
    gpu.setForeground(0xFFFFFF)
    gpu.set(5+8*16, 3+3*8, "<" .. temp_1)
    
    draw_fuel_pos(16, 9, (temp_1 + temp_2) / 2, max_temp)
    gpu.setForeground(0xFFFFFF)
    gpu.set(5+8*16, 3+3*9, "<" .. temp_2)
    
    draw_fuel_pos(16, 10, (temp_2 + temp_3) / 2, max_temp)
    gpu.setForeground(0xFFFFFF)
    gpu.set(5+8*16, 3+3*10, "<" .. temp_3)
    
    draw_fuel_pos(16, 11, (temp_3 + temp_4) / 2, max_temp)
    gpu.setForeground(0xFFFFFF)
    gpu.set(5+8*16, 3+3*11, "<" .. temp_4)
    
    draw_fuel_pos(16, 12, (temp_4 + temp_5) / 2, max_temp)
    gpu.setForeground(0xFFFFFF)
    gpu.set(5+8*16, 3+3*12, "<" .. temp_5)
    
    draw_fuel_pos(16, 13, max_temp, max_temp)
    gpu.setForeground(0xFFFFFF)
    gpu.set(5+8*16, 3+3*13, max_temp .. "+")
end

-- 检查数据是否变化
local function has_data_changed(x, y, info)
    if not last_component_data[x][y].type then
        return true  -- 第一次获取数据
    end
    
    -- 检查类型是否变化
    if last_component_data[x][y].type ~= info.type then
        return true
    end
    
    -- 根据类型检查关键数据是否变化
    if info.type == "FUEL" or info.type == "FUEL_SIM" then
        return last_component_data[x][y].coreSkinTemp ~= info.coreSkinTemp or
               last_component_data[x][y].enrichment ~= info.enrichment or
               last_component_data[x][y].xenon ~= info.xenon
    elseif info.type == "CONTROL" then
        return last_component_data[x][y].level ~= info.level
    end
    
    return false
end

-- 获取最高温度和氙中毒程度
local function get_max_values()
    local max_temp = 0
    local max_xenon = 0
    
    for x = 0, 14 do
        for y = 0, 14 do
            local info = reactor_console.getColumnData(x, y)
            if info and (info.type == "FUEL" or info.type == "FUEL_SIM") then
                if info.coreSkinTemp and info.coreSkinTemp > max_temp then
                    max_temp = info.coreSkinTemp
                end
                if info.xenon and info.xenon > max_xenon then
                    max_xenon = info.xenon
                end
            end
        end
    end
    
    return max_temp, max_xenon
end

-- 自动紧急停堆检查
local function auto_emergency_check()
    if not settings.auto_emergency then
        return false
    end
    
    local max_temp, max_xenon = get_max_values()
    
    -- 检查温度是否超过阈值
    if max_temp > settings.max_temperature * settings.temperature_threshold then
        set_status_message("警告: 温度过高! " .. max_temp .. "°C > " .. 
                          settings.max_temperature * settings.temperature_threshold .. "°C")
        
        if max_temp >= settings.max_temperature then
            set_status_message("紧急: 温度超过安全限制! 执行自动停堆")
            perform_az5()
            return true
        end
    end
    
    -- 检查氙中毒是否超过阈值
    if max_xenon > settings.xenon_threshold then
        set_status_message("警告: 氙中毒过高! " .. string.format("%.3f", max_xenon) .. " > " .. 
                          string.format("%.3f", settings.xenon_threshold))
        
        if max_xenon >= 0.95 then  -- 接近1.0时紧急停堆
            set_status_message("紧急: 氙中毒超过安全限制! 执行自动停堆")
            perform_az5()
            return true
        end
    end
    
    return false
end

-- 执行AZ-5紧急停堆
function perform_az5()
    set_status_message("执行紧急停止 (AZ-5)...")
    local success = pcall(function()
        return reactor_console.pressAZ5()
    end)
    if success then
        set_status_message("紧急停止已执行")
    else
        set_status_message("执行紧急停止失败")
    end
    return success
end

-- 绘制反应堆网格
function draw_reactor_grid()
    local any_changed = false
    
    -- 绘制网格边框
    gpu.setForeground(0x333333)
    for i = 0, 14 do
        -- 垂直线
        gpu.set(5 + i * 8, 3, "│")  -- 加宽网格
        gpu.set(5 + i * 8, 3 + 14 * 3, "│")
        -- 水平线
        if i <= 14 then
            gpu.set(5, 3 + i * 3, "─")
            gpu.set(5 + 14 * 8, 3 + i * 3, "─")  -- 加宽网格
        end
    end
    
    -- 绘制交叉点
    for x = 0, 14 do
        for y = 0, 14 do
            gpu.set(5 + x * 8, 3 + y * 3, "┼")  -- 加宽网格
        end
    end
    
    -- 获取并绘制每个柱子的数据
    for ix = 0, 14 do
        for iy = 0, 14 do
            local info = reactor_console.getColumnData(ix, iy)
            
            if info == nil then
                -- 跳过空位置
            elseif has_data_changed(ix, iy, info) then
                any_changed = true
                
                -- 存储当前数据
                last_component_data[ix][iy] = {
                    type = info.type,
                    coreSkinTemp = info.coreSkinTemp,
                    enrichment = info.enrichment,
                    level = info.level,
                    xenon = info.xenon
                }
                
                if info.type == 'OUTGASSER' then
                    -- 辐照通道
                    gpu.setBackground(0x5A5A5A)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, "※")  -- 加宽网格
                elseif info.type == 'CONTROL' then
                    -- 控制棒
                    draw_control_pos(ix, iy, info.level)
                elseif info.type == 'FUEL' or info.type == 'FUEL_SIM' then
                    -- 燃料棒
                    draw_fuel_pos(ix, iy, info.coreSkinTemp, settings.max_temperature)
                    -- 显示富集度
                    gpu.setForeground(0xFFFFFF)
                    gpu.set(5+8*ix, 3+3*iy, string.format("%.2f", info.enrichment))
                    -- 显示氙中毒程度（如果较高）
                    if info.xenon and info.xenon > 0.5 then
                        gpu.setForeground(0xFF00FF)
                        gpu.set(5+8*ix+4, 3+3*iy, string.format("%.2f", info.xenon))
                    end
                elseif info.type == 'BOILER' then
                    -- 锅炉 (rbmk_boiler)
                    gpu.setBackground(0xFFFF00)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, " ")  -- 加宽网格
                    gpu.setForeground(0x000000)
                    gpu.set(5+8*ix+3, 3+3*iy+1, "B")
                elseif info.type == 'ABSORBER' then
                    -- 中子吸收剂
                    gpu.setBackground(0x008800)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, " ")  -- 加宽网格
                    gpu.setForeground(0x000000)
                    gpu.set(5+8*ix+3, 3+3*iy+1, "A")
                elseif info.type == 'COOLER' then
                    -- 冷却器
                    gpu.setBackground(0x00FFFF)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, " ")  -- 加宽网格
                    gpu.setForeground(0x000000)
                    gpu.set(5+8*ix+3, 3+3*iy+1, "C")
                elseif info.type == 'HEATEX' then
                    -- 热交换器
                    gpu.setBackground(0xFF8000)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, " ")  -- 加宽网格
                    gpu.setForeground(0x000000)
                    gpu.set(5+8*ix+3, 3+3*iy+1, "H")
                elseif info.type == 'MODERATOR' then
                    -- 慢化剂
                    gpu.setBackground(0x888888)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, " ")  -- 加宽网格
                    gpu.setForeground(0x000000)
                    gpu.set(5+8*ix+3, 3+3*iy+1, "M")
                elseif info.type == 'REFLECTOR' then
                    -- 反射器
                    gpu.setBackground(0xCCCCCC)
                    gpu.fill(5+8*ix, 3+3*iy, 8, 3, " ")  -- 加宽网格
                    gpu.setForeground(0x000000)
                    gpu.set(5+8*ix+3, 3+3*iy+1, "R")
                end
            end
            
            -- 绘制选中框
            if ix == selected_x and iy == selected_y then
                gpu.setForeground(0xFFFFFF)
                gpu.set(5+8*ix, 3+3*iy, "┌")      -- 加宽网格
                gpu.set(5+8*ix+7, 3+3*iy, "┐")    -- 加宽网格
                gpu.set(5+8*ix, 3+3*iy+2, "└")    -- 加宽网格
                gpu.set(5+8*ix+7, 3+3*iy+2, "┘")  -- 加宽网格
            end
        end
    end
    
    return any_changed
end

-- 绘制状态栏
function draw_status_bar()
    local status_y = SCREEN_HEIGHT - 5
    
    -- 清空状态区域
    gpu.setBackground(0x000000)
    gpu.fill(1, status_y, SCREEN_WIDTH, 5, " ")
    
    -- 显示状态信息
    gpu.setForeground(0xFFFFFF)
    gpu.set(2, status_y + 1, "状态: ")
    
    -- 获取反应堆总体状态
    local total_temp = 0
    local rod_count = 0
    local max_temp = 0
    local max_xenon = 0
    local control_rods = 0
    local control_level = 0
    
    for x = 0, 14 do
        for y = 0, 14 do
            local info = reactor_console.getColumnData(x, y)
            if info then
                if info.type == "FUEL" or info.type == "FUEL_SIM" then
                    local temp = info.coreSkinTemp or 0
                    total_temp = total_temp + temp
                    rod_count = rod_count + 1
                    if temp > max_temp then
                        max_temp = temp
                    end
                    if info.xenon and info.xenon > max_xenon then
                        max_xenon = info.xenon
                    end
                elseif info.type == "CONTROL" then
                    control_rods = control_rods + 1
                    control_level = control_level + (info.level or 0)
                end
            end
        end
    end
    
    local avg_temp = rod_count > 0 and total_temp / rod_count or 0
    
    -- 显示温度信息
    gpu.set(2, status_y + 2, "平均温度: " .. string.format("%.1f", avg_temp) .. "°C")
    gpu.set(2, status_y + 3, "最高温度: " .. string.format("%.1f", max_temp) .. "°C")
    
    -- 显示氙中毒信息
    if max_xenon > 0 then
        gpu.set(2, status_y + 4, "最高氙中毒: " .. string.format("%.3f", max_xenon))
    end
    
    -- 显示温度状态
    local status = "正常"
    local status_color = 0x00FF00
    
    if max_temp >= settings.max_temperature * settings.temperature_threshold then
        status = "警告"
        status_color = 0xFFFF00
    end
    
    if max_temp >= settings.max_temperature then
        status = "危险!"
        status_color = 0xFF0000
    end
    
    gpu.setForeground(status_color)
    gpu.set(30, status_y + 2, "状态: " .. status)
    
    -- 显示控制棒信息
    gpu.setForeground(0xFFFFFF)
    gpu.set(30, status_y + 3, "控制棒: ")
    
    if control_rods > 0 then
        control_level = control_level / control_rods
        gpu.set(38, status_y + 3, string.format("%.1f%%", control_level * 100))
    end
    
    -- 显示选中位置
    gpu.set(30, status_y + 4, "选中: " .. selected_x .. "," .. selected_y)
    
    -- 显示状态消息
    if os.time() - message_time < 5 then  -- 显示5秒
        gpu.set(60, status_y + 2, status_message)
    else
        status_message = ""
    end
    
    -- 显示设置信息
    gpu.set(60, status_y + 3, "最高温度: " .. settings.max_temperature .. "°C")
    gpu.set(60, status_y + 4, "自动保护: " .. (settings.auto_emergency and "开启" or "关闭"))
    
    -- 显示时间
    local time = os.date("%H:%M:%S")
    gpu.set(SCREEN_WIDTH - 10, status_y + 2, time)
    
    -- 显示控制提示
    gpu.set(1, status_y + 5, "方向键:移动选中  +/-:调整控制棒  A:AZ-5急停  M:返回菜单  S:设置  Q:退出")
end

-- 显示组件详细信息
function show_component_info(x, y)
    local info = reactor_console.getColumnData(x, y)
    if not info then
        set_status_message("错误: 该位置没有组件")
        return
    end
    
    local msg = "位置: " .. x .. "," .. y .. " 类型: " .. (info.type or "未知")
    if info.type == "FUEL" or info.type == "FUEL_SIM" then
        msg = msg .. " 温度: " .. string.format("%.1f", info.coreSkinTemp or 0) .. "°C"
        if info.xenon then
            msg = msg .. " 氙中毒: " .. string.format("%.3f", info.xenon)
        end
    elseif info.type == "CONTROL" then
        msg = msg .. " 水平: " .. string.format("%.3f", info.level or 0)
    end
    
    set_status_message(msg)
end

-- 设置状态消息
function set_status_message(msg)
    status_message = msg
    message_time = os.time()
end

-- 绘制菜单
function draw_menu()
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, SCREEN_WIDTH, SCREEN_HEIGHT, " ")
    
    -- 在左上角添加注释区域
    gpu.setForeground(0x888888)
    gpu.set(2, 2, "=== RBMK反应堆监控系统 ===")
    gpu.set(2, 3, "版本: 1.0")
    gpu.set(2, 4, "作者: AH-64HD（负责调教ai），deepseek（负责被调教和写代码）")
    gpu.set(2, 5, "描述: 用于监控RBMK反应堆状态，功能并不完美，出了什么问题以后再说[doge]")
    gpu.set(2, 6, "提示: 使用方向键和E键导航")
    
    -- 绘制标题
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(SCREEN_WIDTH/2) - 10, 10, "RBMK反应堆监控系统")
    gpu.set(math.floor(SCREEN_WIDTH/2) - 15, 11, "==============================")
    
    -- 绘制菜单选项
    local menu_items = {
        "启动监控",
        "设置最高温度 (" .. settings.max_temperature .. "°C)",
        "设置控制棒水平 (" .. string.format("%.3f", settings.control_rod_level) .. ")",
        "自动紧急停堆 (" .. (settings.auto_emergency and "开启" or "关闭") .. ")",
        "设置氙中毒阈值 (" .. string.format("%.3f", settings.xenon_threshold) .. ")",
        "设置温度阈值 (" .. string.format("%.1f", settings.temperature_threshold * 100) .. "%)",
        "退出程序"
    }
    
    for i, item in ipairs(menu_items) do
        if i == menu_selection then
            gpu.setBackground(0x444444)
            gpu.setForeground(0xFFFFFF)
        else
            gpu.setBackground(0x000000)
            gpu.setForeground(0xAAAAAA)
        end
        
        gpu.fill(math.floor(SCREEN_WIDTH/2) - 15, 13 + i * 2, 30, 1, " ")
        gpu.set(math.floor(SCREEN_WIDTH/2) - 14, 13 + i * 2, item)
    end
    
    -- 绘制提示
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.set(2, SCREEN_HEIGHT - 2, "方向键:选择  E:确认  Q:退出")
end

-- 绘制设置界面
function draw_settings()
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, SCREEN_WIDTH, SCREEN_HEIGHT, " ")
    
    -- 绘制标题
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(SCREEN_WIDTH/2) - 5, 5, "系统设置")
    
    -- 绘制设置选项
    local settings_items = {
        "最高温度: " .. settings.max_temperature .. "°C",
        "控制棒水平: " .. string.format("%.9f", settings.control_rod_level),
        "自动紧急停堆: " .. (settings.auto_emergency and "开启" or "关闭"),
        "氙中毒阈值: " .. string.format("%.3f", settings.xenon_threshold),
        "温度阈值: " .. string.format("%.1f", settings.temperature_threshold * 100) .. "%",
        "返回主菜单"
    }
    
    for i, item in ipairs(settings_items) do
        if i == menu_selection then
            gpu.setBackground(0x444444)
            gpu.setForeground(0xFFFFFF)
        else
            gpu.setBackground(0x000000)
            gpu.setForeground(0xAAAAAA)
        end
        
        gpu.fill(math.floor(SCREEN_WIDTH/2) - 15, 8 + i * 2, 30, 1, " ")
        gpu.set(math.floor(SCREEN_WIDTH/2) - 14, 8 + i * 2, item)
    end
    
    -- 绘制提示
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.set(2, SCREEN_HEIGHT - 2, "方向键:选择  E:修改  M:返回菜单  Q:退出")
end

-- 绘制输入界面
function draw_input()
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, SCREEN_WIDTH, SCREEN_HEIGHT, " ")
    
    -- 绘制标题
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(SCREEN_WIDTH/2) - 5, 5, "输入设置")
    
    -- 绘制提示和默认值
    gpu.set(math.floor(SCREEN_WIDTH/2) - 20, 8, input_prompt)
    gpu.set(math.floor(SCREEN_WIDTH/2) - 20, 9, "当前值: " .. input_default)
    gpu.set(math.floor(SCREEN_WIDTH/2) - 20, 10, "请输入新值:")
    
    -- 绘制输入框
    gpu.setBackground(0x444444)
    gpu.fill(math.floor(SCREEN_WIDTH/2) - 20, 12, 40, 1, " ")
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(SCREEN_WIDTH/2) - 19, 12, input_buffer .. "_")
    
    -- 绘制提示
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.set(2, SCREEN_HEIGHT - 2, "E:确认  Q:取消")
end

-- 处理菜单输入
function handle_menu_input()
    local event_data = {event.pull(0.1)}
    if #event_data == 0 then
        return true
    end
    
    local event_type = event_data[1]
    
    if event_type == "key_down" then
        local char = event_data[3]
        local key = event_data[4]
        
        -- 方向键移动选择
        if key == 200 then -- 上箭头
            menu_selection = math.max(1, menu_selection - 1)
            return true
        elseif key == 208 then -- 下箭头
            if current_screen == "menu" then
                menu_selection = math.min(7, menu_selection + 1)
            else
                menu_selection = math.min(6, menu_selection + 1)
            end
            return true
            
        -- 确认选择 (按E键)
        elseif char == 101 or char == 69 then -- 'E' 或 'e'键
            if current_screen == "menu" then
                if menu_selection == 1 then
                    current_screen = "monitor"
                    set_status_message("进入监控模式")
                elseif menu_selection == 2 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.max_temperature)
                    input_prompt = "请输入最高温度 (°C):"
                    return true
                elseif menu_selection == 3 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.control_rod_level)
                    input_prompt = "请输入控制棒水平 (0.0-1.0):"
                    return true
                elseif menu_selection == 4 then
                    settings.auto_emergency = not settings.auto_emergency
                    set_status_message("自动紧急停堆: " .. (settings.auto_emergency and "开启" or "关闭"))
                elseif menu_selection == 5 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.xenon_threshold)
                    input_prompt = "请输入氙中毒阈值 (0.0-1.0):"
                    return true
                elseif menu_selection == 6 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.temperature_threshold * 100)
                    input_prompt = "请输入温度阈值百分比 (0-100):"
                    return true
                elseif menu_selection == 7 then
                    return false
                end
            elseif current_screen == "settings" then
                if menu_selection == 1 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.max_temperature)
                    input_prompt = "请输入最高温度 (°C):"
                    return true
                elseif menu_selection == 2 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.control_rod_level)
                    input_prompt = "请输入控制棒水平 (0.0-1.0):"
                    return true
                elseif menu_selection == 3 then
                    settings.auto_emergency = not settings.auto_emergency
                elseif menu_selection == 4 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.xenon_threshold)
                    input_prompt = "请输入氙中毒阈值 (0.0-1.0):"
                    return true
                elseif menu_selection == 5 then
                    input_mode = true
                    input_buffer = ""
                    input_default = tostring(settings.temperature_threshold * 100)
                    input_prompt = "请输入温度阈值百分比 (0-100):"
                    return true
                elseif menu_selection == 6 then
                    current_screen = "menu"
                    menu_selection = 1
                end
            end
            return true
            
        -- 退出程序 (按Q键)
        elseif char == 113 or char == 81 then -- 'Q' 或 'q'
            return false
        end
    end
    
    return true
end

-- 处理设置输入
function handle_settings_input()
    local event_data = {event.pull(0.1)}
    if #event_data == 0 then
        return true
    end
    
    local event_type = event_data[1]
    
    if event_type == "key_down" then
        local char = event_data[3]
        local key = event_data[4]
        
        -- 方向键移动选择
        if key == 200 then -- 上箭头
            menu_selection = math.max(1, menu_selection - 1)
            return true
        elseif key == 208 then -- 下箭头
            menu_selection = math.min(6, menu_selection + 1)
            return true
            
        -- 确认选择 (按E键)
        elseif char == 101 or char == 69 then -- 'E' 或 'e'键
            if menu_selection == 1 then
                input_mode = true
                input_buffer = ""
                input_default = tostring(settings.max_temperature)
                input_prompt = "请输入最高温度 (°C):"
                return true
            elseif menu_selection == 2 then
                input_mode = true
                input_buffer = ""
                input_default = tostring(settings.control_rod_level)
                input_prompt = "请输入控制棒水平 (0.0-1.0):"
                return true
            elseif menu_selection == 3 then
                settings.auto_emergency = not settings.auto_emergency
            elseif menu_selection == 4 then
                input_mode = true
                input_buffer = ""
                input_default = tostring(settings.xenon_threshold)
                input_prompt = "请输入氙中毒阈值 (0.0-1.0):"
                return true
            elseif menu_selection == 5 then
                input_mode = true
                input_buffer = ""
                input_default = tostring(settings.temperature_threshold * 100)
                input_prompt = "请输入温度阈值百分比 (0-100):"
                return true
            elseif menu_selection == 6 then
                current_screen = "menu"
                menu_selection = 1
            end
            return true
            
        -- 返回菜单 (按M键)
        elseif char == 109 or char == 77 then -- 'M' 或 'm'
            current_screen = "menu"
            menu_selection = 1
            return true
            
        -- 退出程序 (按Q键)
        elseif char == 113 or char == 81 then -- 'Q' 或 'q'
            return false
        end
    end
    
    return true
end

-- 处理监控输入
function handle_monitor_input()
    local event_data = {event.pull(0.1)}
    if #event_data == 0 then
        return true
    end
    
    local event_type = event_data[1]
    
    if event_type == "key_down" then
        local char = event_data[3]
        local key = event_data[4]
        
        -- 方向键移动选中位置
        if key == 203 then -- 左箭头
            selected_x = math.max(0, selected_x - 1)
            show_component_info(selected_x, selected_y)
            return true
        elseif key == 205 then -- 右箭头
            selected_x = math.min(14, selected_x + 1)
            show_component_info(selected_x, selected_y)
            return true
        elseif key == 200 then -- 上箭头
            selected_y = math.max(0, selected_y - 1)
            show_component_info(selected_x, selected_y)
            return true
        elseif key == 208 then -- 下箭头
            selected_y = math.min(14, selected_y + 1)
            show_component_info(selected_x, selected_y)
            return true
            
        -- 控制棒调整
        elseif char == 43 then -- '+' 键
            settings.control_rod_level = math.min(1.0, settings.control_rod_level + 0.01)
            local success = pcall(function()
                return reactor_console.setLevel(settings.control_rod_level)
            end)
            if success then
                set_status_message("控制棒水平已设置为: " .. string.format("%.9f", settings.control_rod_level))
            else
                set_status_message("设置控制棒失败")
            end
            return true
        elseif char == 45 then -- '-' 键
            settings.control_rod_level = math.max(0.0, settings.control_rod_level - 0.01)
            local success = pcall(function()
                return reactor_console.setLevel(settings.control_rod_level)
            end)
            if success then
                set_status_message("控制棒水平已设置为: " .. string.format("%.9f", settings.control_rod_level))
            else
                set_status_message("设置控制棒失败")
            end
            return true
            
        -- 精确控制棒调整
        elseif char == 93 then -- ']' 键
            input_mode = true
            input_buffer = ""
            input_default = tostring(settings.control_rod_level)
            input_prompt = "请输入控制棒水平 (0.0-1.0):"
            return true
            
        -- AZ-5紧急停止
        elseif char == 97 or char == 65 then -- 'A' 或 'a'
            perform_az5()
            return true
            
        -- 返回菜单
        elseif char == 109 or char == 77 then -- 'M' 或 'm'
            current_screen = "menu"
            menu_selection = 1
            return true
            
        -- 打开设置
        elseif char == 115 or char == 83 then -- 'S' 或 's'
            current_screen = "settings"
            menu_selection = 1
            return true
            
        -- 退出程序 (按Q键)
        elseif char == 113 or char == 81 then -- 'Q' 或 'q'
            return false
        end
    end
    
    return true
end

-- 处理输入模式
function handle_input_mode()
    local event_data = {event.pull(0.1)}
    if #event_data == 0 then
        return true
    end
    
    local event_type = event_data[1]
    
    if event_type == "key_down" then
        local char = event_data[3]
        local key = event_data[4]
        
        -- E键确认输入
        if char == 101 or char == 69 then -- 'E' 或 'e'键
            input_mode = false
            local value = tonumber(input_buffer)
            
            if value then
                if input_prompt:find("最高温度") then
                    if value >= 1000 and value <= 10000 then
                        settings.max_temperature = value
                        set_status_message("最高温度已设置为: " .. value .. "°C")
                    else
                        set_status_message("错误: 温度必须在1000-10000°C之间")
                    end
                elseif input_prompt:find("控制棒水平") then
                    if value >= 0 and value <= 1 then
                        settings.control_rod_level = value
                        local success = pcall(function()
                            return reactor_console.setLevel(settings.control_rod_level)
                        end)
                        if success then
                            set_status_message("控制棒水平已设置为: " .. string.format("%.9f", settings.control_rod_level))
                        else
                            set_status_message("设置控制棒失败")
                        end
                    else
                        set_status_message("错误: 控制棒水平必须在0.0-1.0之间")
                    end
                elseif input_prompt:find("氙中毒阈值") then
                    if value >= 0 and value <= 1 then
                        settings.xenon_threshold = value
                        set_status_message("氙中毒阈值已设置为: " .. string.format("%.3f", value))
                    else
                        set_status_message("错误: 氙中毒阈值必须在0.0-1.0之间")
                    end
                elseif input_prompt:find("温度阈值百分比") then
                    if value >= 50 and value <= 100 then
                        settings.temperature_threshold = value / 100
                        set_status_message("温度阈值已设置为: " .. value .. "%")
                    else
                        set_status_message("错误: 温度阈值必须在50-100%之间")
                    end
                end
            else
                set_status_message("错误: 请输入有效的数字")
            end
            
            return true
            
        -- 退格键删除字符
        elseif key == 8 then
            if #input_buffer > 0 then
                input_buffer = input_buffer:sub(1, -2)
            end
            return true
            
        -- Q键取消输入
        elseif char == 113 or char == 81 then -- 'Q' 或 'q'
            input_mode = false
            return true
            
        -- 数字和小数点输入
        elseif (char >= 48 and char <= 57) or char == 46 then
            input_buffer = input_buffer .. string.char(char)
            return true
        end
    end
    
    return true
end

-- 主监控循环
function main_loop()
    local running = true
    
    while running do
        -- 处理输入模式
        if input_mode then
            draw_input()
            running = handle_input_mode()
        else
            -- 根据当前屏幕绘制相应界面
            if current_screen == "menu" then
                draw_menu()
                running = handle_menu_input()
            elseif current_screen == "settings" then
                draw_settings()
                running = handle_settings_input()
            elseif current_screen == "monitor" then
                local current_time = os.time()
                
                -- 检查数据变化并绘制网格
                local grid_changed = draw_reactor_grid()
                
                -- 定期更新界面
                if grid_changed or (current_time - last_redraw_time >= 1) then
                    -- 绘制温度标尺
                    draw_temperature_scale(settings.max_temperature)
                    
                    -- 绘制状态栏
                    draw_status_bar()
                    
                    last_redraw_time = current_time
                end
                
                -- 自动紧急停堆检查
                auto_emergency_check()
                
                -- 处理监控输入
                running = handle_monitor_input()
            end
        end
        
        -- 短暂延迟，减少CPU占用
        os.sleep(0.05)
    end
end

-- 主程序
function main()
    term.clear()
    print("RBMK反应堆监控系统启动中...")
    
    if init() then
        print("系统初始化完成，开始监控...")
        set_status_message("欢迎使用RBMK反应堆监控系统")
        main_loop()
    else
        print("初始化失败，请检查硬件连接")
    end
    
    -- 恢复屏幕
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, SCREEN_WIDTH, SCREEN_HEIGHT, " ")
    term.clear()
    print("程序已退出")
end

-- 运行主程序
main()