-- jhjm.lua - 增强版文件浏览器 (添加文件夹改名功能)
local event = require("event")
local term = require("term")
local fs = require("filesystem")
local shell = require("shell")

-- 全局变量
local currentDir = ""
local files = {}
local width, height = term.getViewport()

-- 检查是否可以重命名指定路径
function canRename(path)
    -- 获取路径深度
    local depth = 0
    for part in path:gmatch("[^/]+") do
        depth = depth + 1
    end
    
    -- 根目录下一级的文件/文件夹不能重命名
    if depth <= 1 then
        return false, "不能重命名根目录下的文件/文件夹"
    end
    
    -- 检查是否是特殊目录
    local specialDirs = {"/lib", "/bin", "/etc", "/home", "/tmp", "/usr"}
    for _, dir in ipairs(specialDirs) do
        if path == dir then
            return false, "不能重命名系统目录: " .. dir
        end
    end
    
    return true
end

-- 重命名文件或文件夹
function renameItem(oldPath, newName)
    local canRename, reason = canRename(oldPath)
    if not canRename then
        return false, reason
    end
    
    local newPath = fs.concat(fs.path(oldPath), newName)
    
    -- 检查新路径是否已存在
    if fs.exists(newPath) then
        return false, "目标名称已存在"
    end
    
    -- 执行重命名
    local result, reason = fs.rename(oldPath, newPath)
    if not result then
        return false, "重命名失败: " .. tostring(reason)
    end
    
    return true
end

-- 获取目录内容
function listFiles(path)
    local items = {}
    
    -- 添加上级目录选项（如果不是根目录）
    if path ~= "" then
        table.insert(items, {"[返回上级目录]", true, true}) -- true表示是目录，第三个true表示是特殊项
    end
    
    -- 获取当前目录下的所有文件和文件夹
    for item in fs.list(path) do
        local fullPath = fs.concat(path, item)
        local isDir = fs.isDirectory(fullPath)
        table.insert(items, {item, isDir, false}) -- false表示不是特殊项
    end
    
    -- 按目录和文件排序
    table.sort(items, function(a, b)
        if a[2] and not b[2] then
            return true
        elseif not a[2] and b[2] then
            return false
        else
            return a[1]:lower() < b[1]:lower()
        end
    end)
    
    return items
end

-- 显示文件列表
function displayFiles()
    term.clear()
    term.setCursor(1, 1)
    print("JHJM 文件浏览器 - 当前目录: " .. (currentDir == "" and "/" or currentDir))
    print(string.rep("-", width))
    
    files = listFiles(currentDir)
    
    -- 显示编号列表
    for i, file in ipairs(files) do
        if file[3] then -- 特殊项（返回上级目录）
            print(i .. ". " .. file[1])
        elseif file[2] then -- 目录
            print(i .. ". [" .. file[1] .. "]")
        else -- 文件
            print(i .. ". " .. file[1])
        end
    end
    
    print(string.rep("-", width))
    print("请输入数字选择文件/目录 (0: 退出)")
    print("输入 'r数字' 重命名文件/目录 (例如: r1)")
    print("输入 'n' 创建新文件夹")
end

-- 处理文件选择
function handleSelection(choice)
    if choice == 0 then
        term.clear()
        term.setCursor(1, 1)
        print("感谢使用JHJM文件浏览器")
        return false -- 退出程序
    end
    
    if choice < 1 or choice > #files then
        print("无效选择，请重新输入")
        return true -- 继续程序
    end
    
    local selected = files[choice]
    if not selected then
        print("无效选择，请重新输入")
        return true -- 继续程序
    end
    
    if selected[2] then -- 是目录
        if selected[3] then -- 特殊项（返回上级目录）
            currentDir = fs.path(currentDir) or ""
        else -- 普通目录
            currentDir = fs.concat(currentDir, selected[1])
        end
        displayFiles()
    else -- 是文件
        local fullPath = fs.concat(currentDir, selected[1])
        if fs.isDirectory(fullPath) then
            currentDir = fullPath
            displayFiles()
        else
            term.clear()
            term.setCursor(1, 1)
            local result = shell.execute(fullPath)
            print("程序执行完毕，返回代码: " .. tostring(result))
            print("按回车键继续...")
            io.read()
            displayFiles()
        end
    end
    
    return true -- 继续程序
end

-- 处理重命名命令
function handleRename(command)
    -- 提取数字部分
    local numStr = command:sub(2)
    local choice = tonumber(numStr)
    
    if not choice or choice < 1 or choice > #files then
        print("无效的选择编号: " .. numStr)
        return true
    end
    
    local selected = files[choice]
    if not selected then
        print("无效的选择")
        return true
    end
    
    -- 检查是否是特殊项（如返回上级目录）
    if selected[3] then
        print("不能重命名特殊项")
        return true
    end
    
    local oldPath = fs.concat(currentDir, selected[1])
    
    -- 检查是否可以重命名
    local canRename, reason = canRename(oldPath)
    if not canRename then
        print(reason)
        return true
    end
    
    -- 获取新名称
    print("当前名称: " .. selected[1])
    print("请输入新名称:")
    local newName = io.read()
    
    if not newName or newName == "" then
        print("名称不能为空")
        return true
    end
    
    -- 执行重命名
    local success, reason = renameItem(oldPath, newName)
    if success then
        print("重命名成功")
    else
        print("重命名失败: " .. tostring(reason))
    end
    
    os.sleep(1)
    displayFiles()
    return true
end

-- 创建新文件夹
function createNewFolder()
    print("请输入新文件夹名称:")
    local folderName = io.read()
    
    if not folderName or folderName == "" then
        print("文件夹名称不能为空")
        return true
    end
    
    local fullPath = fs.concat(currentDir, folderName)
    
    -- 检查是否已存在
    if fs.exists(fullPath) then
        print("文件夹已存在: " .. folderName)
        return true
    end
    
    -- 创建文件夹
    local result = fs.makeDirectory(fullPath)
    if result then
        print("文件夹创建成功: " .. folderName)
    else
        print("文件夹创建失败: " .. folderName)
    end
    
    os.sleep(1)
    displayFiles()
    return true
end

-- 主函数
function main()
    currentDir = shell.getWorkingDirectory()
    displayFiles()
    
    while true do
        -- 获取用户输入
        term.write("> ")
        local input = io.read()
        
        -- 处理输入
        if input == nil then
            break -- 输入结束（通常是Ctrl+D）
        end
        
        input = input:gsub("^%s*(.-)%s*$", "%1") -- 去除首尾空白
        
        if input == "" then
            -- 空输入，重新显示
            displayFiles()
        elseif input:sub(1, 1) == "r" then
            -- 重命名命令
            if not handleRename(input) then
                break
            end
        elseif input:lower() == "n" then
            -- 创建新文件夹
            if not createNewFolder() then
                break
            end
        else
            -- 尝试转换为数字
            local choice = tonumber(input)
            
            if choice then
                -- 数字输入
                if not handleSelection(choice) then
                    break -- 退出程序
                end
            else
                -- 非数字输入，检查特殊命令
                if input:lower() == "q" or input:lower() == "exit" or input:lower() == "quit" then
                    term.clear()
                    term.setCursor(1, 1)
                    print("感谢使用JHJM文件浏览器")
                    break
                else
                    print("无效输入，请输入数字 (0: 退出) 或 r数字 (重命名) 或 n (新建文件夹)")
                end
            end
        end
    end
end

-- 错误处理
local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursor(1, 1)
    print("程序发生错误: " .. tostring(err))
    print("按回车键退出...")
    io.read()
end