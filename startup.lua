--============================================================--
-- MiniOS v0.6 – Taskbar klickbar, auch wenn App läuft
--============================================================--

local term, fs, shell, os, window, colors =
      term, fs, shell, os, window, colors

------------------------ Monitor ------------------------------
local mon = peripheral.find("monitor")
if mon then
    term.redirect(mon)
end
local screen = term.current()
local w, h = screen.getSize()

---------------------------------------------------------------
-- Konfiguration
---------------------------------------------------------------
local APP_DIR = "osapps"
if not fs.exists(APP_DIR) then fs.makeDir(APP_DIR) end
local BAR_WIDTH = 9

-- Buttons in der Taskbar
local buttons = {
    { name="SCADA",   label="SCADA",  action=function() runApp("scada_setup") end },
    { name="AE2",     label="AE2",    action=function() runApp("ae2_install") end},  
    { name="music",   label="Music",  action=function() runApp("music") end },
    { name="sonstige", label="Sonstige", action=function() runApp("sonstige") end},
    { name="shell",   label="Shell",  action=function() shellWindow() end },
    { name="reboot",  label="Reboot", action=function() os.reboot() end },
    { name="off",     label="Off",    action=function() os.shutdown() end },
}

---------------------------------------------------------------
-- App-Fenster
---------------------------------------------------------------
local function createAppWindow()
    w, h = screen.getSize()
    return window.create(screen,
        BAR_WIDTH + 1, 1,
        math.max(1, w - BAR_WIDTH), h, true)
end

local appWin = createAppWindow()
appWin.setBackgroundColor(colors.white)
appWin.setTextColor(colors.black)
appWin.clear()

---------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------
local function appCenterWrite(y, text)
    local aw = ({ appWin.getSize() })[1]
    local x = math.max(1, math.floor((aw - #text) / 2) + 1)
    appWin.setCursorPos(x, y)
    appWin.write(text)
end

local function drawTaskbar()
    w, h = screen.getSize()
    screen.setBackgroundColor(colors.lightGray)
    screen.setTextColor(colors.white)
    for y = 1, h do
        screen.setCursorPos(1, y)
        screen.write(string.rep(" ", BAR_WIDTH))
    end
    local yPos = 2
    for _, b in ipairs(buttons) do
        if yPos <= h then
            screen.setCursorPos(2, yPos)
            local lbl = #b.label > BAR_WIDTH-2 and b.label:sub(1, BAR_WIDTH-2) or b.label
            screen.write(lbl .. string.rep(" ", BAR_WIDTH-2-#lbl))
        end
        yPos = yPos + 2
    end
    screen.setBackgroundColor(colors.white)
    screen.setTextColor(colors.black)
end

local function detectButton(mx, my)
    if mx <= BAR_WIDTH then
        local yPos = 2
        for _, b in ipairs(buttons) do
            if my == yPos then return b end
            yPos = yPos + 2
        end
    end
    return nil
end

---------------------------------------------------------------
-- App-Management
---------------------------------------------------------------
function runScript(name)
    appWin.setBackgroundColor(colors.black)
    shell.run("osapps\\ccmsi install rtu main")
    sleep(2)
    shell.run("y")


end


function runApp(name)
    local path = fs.combine(APP_DIR, name .. ".lua")
    appWin = createAppWindow()
    appWin.setBackgroundColor(colors.black)
    appWin.clear()
    appWin.setCursorPos(1,1)

    if not fs.exists(path) then
        appWin.write("App nicht gefunden: "..name)
        appWin.setBackgroundColor(colors.black)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/other_install.lua osapps/sonstige.lua")
        sleep(0.1)
        shell.run("wget https://raw.githubusercontent.com/SirEndii/Lua-Projects/master/src/installer.lua installer")
        sleep(0.1)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/ae2_install.lua osapps/ae2_install.lua")
        sleep(0.1)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/scada_setup.lua osapps/scada_setup.lua")
        sleep(0.1)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/ccmsi.lua osapps/ccmsi.lua")
        sleep(0.1)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/music.lua osapps/music.lua")
        sleep(0.1)
        shell.run("wget https://raw.githubusercontent.com/SirEndii/Lua-Projects/refs/heads/master/src/installer.lua")
        sleep(0.1)
        os.reboot()
        return
    end

    -- App in Coroutine starten, damit Taskbar parallel geprüft wird
    local function appRoutine()
        local ok, err = pcall(function()
            term.redirect(appWin)
            shell.run(path)
        end)
        term.redirect(screen)
        if not ok then
            appWin.setTextColor(colors.white)
            appWin.setCursorPos(1,1)
            appWin.write("Fehler:\n"..err)
        end
    end

    -- Taskbar-Listener – erlaubt Buttons während App läuft
    local function barRoutine()
        while true do
            local ev = { os.pullEvent() }
            if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
                -- Korrektur: mx/my immer aus den letzten beiden Werten
                local mx, my = ev[#ev-1], ev[#ev]
                local btn = detectButton(mx, my)
                if btn then
                    return btn  -- Button geklickt -> App verlassen
                end
            elseif ev[1] == "monitor_resize" then
                drawTaskbar()
                appWin = createAppWindow()
            end
        end
    end

    drawTaskbar()
    parallel.waitForAny(appRoutine, barRoutine)
    drawTaskbar()  -- Taskbar nach App-Ende neu zeichnen
end

function shellWindow()
    appWin = createAppWindow()
    appWin.clear()
    appWin.setCursorPos(1,1)
    term.redirect(appWin)
    shell.run("shell")
    term.redirect(screen)
end

---------------------------------------------------------------
-- Boot & Hauptschleife
---------------------------------------------------------------
local function bootScreen()
    drawTaskbar()
    appCenterWrite(math.floor(h/2), "Biddi OS v0.6 startet...")
    os.sleep(0.5)
end

local function main()
    bootScreen()
    drawTaskbar()
    appWin.clear()
    appCenterWrite(math.floor(h/2), "Nichts offen...")

    while true do
        local ev = { os.pullEvent() }

        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local mx, my = ev[#ev-1], ev[#ev]
            local btn = detectButton(mx, my)
            if btn then
                btn.action()
            end

        elseif ev[1] == "monitor_resize" then
            drawTaskbar()
            appWin = createAppWindow()
            appWin.clear()
            appCenterWrite(math.floor(h/2), "Monitor angepasst")

        elseif ev[1] == "key" then
            local k = keys.getName(ev[2])
            if k == "escape" then os.shutdown() end
        end
    end
end

---------------------------------------------------------------
-- Start
---------------------------------------------------------------
local ok, err = pcall(main)
if not ok then
    term.redirect(screen)
    term.clear()
    term.setCursorPos(1,1)
    print("Biddi OS-Fehler:")
    print(err)
    print("Taste für Shell drücken.")
    os.pullEvent("key")
    shell.run("shell")
end















