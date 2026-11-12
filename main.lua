--!strict
-- ============================================================
--   VoidHub — single-file build
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/YOU/voidhub/main/voidhub.lua"))()
-- ============================================================

if _G.VoidHub and _G.VoidHub.Unload then pcall(_G.VoidHub.Unload) end

local VERSION = "1.0.0"

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local CoreGui         = game:GetService("CoreGui")
local Lighting        = game:GetService("Lighting")
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser     = game:GetService("VirtualUser")
local Workspace       = workspace

local LP = Players.LocalPlayer
assert(LP, "VoidHub: no LocalPlayer")

-- ============================================================
--   THEME + UI PRIMITIVES
-- ============================================================
local THEME = {
    Bg = Color3.fromRGB(14,14,18), Bg2 = Color3.fromRGB(20,20,26),
    Bg3 = Color3.fromRGB(28,28,36), Stroke = Color3.fromRGB(44,44,56),
    Text = Color3.fromRGB(230,230,240), TextMuted = Color3.fromRGB(150,150,165),
    Accent = Color3.fromRGB(140,90,255), AccentDim = Color3.fromRGB(80,50,170),
    Danger = Color3.fromRGB(240,80,100), Ok = Color3.fromRGB(90,230,150),
    Radius = UDim.new(0,8), Font = Enum.Font.GothamMedium, FontBold = Enum.Font.GothamBold,
}

local function new(cls, props, children)
    local o = Instance.new(cls)
    for k,v in pairs(props or {}) do o[k] = v end
    for _,c in ipairs(children or {}) do c.Parent = o end
    return o
end
local function corner(r) return new("UICorner",{CornerRadius=r or THEME.Radius}) end
local function stroke(c,t) return new("UIStroke",{Color=c or THEME.Stroke,Thickness=t or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function pad(n) return new("UIPadding",{PaddingTop=UDim.new(0,n),PaddingBottom=UDim.new(0,n),PaddingLeft=UDim.new(0,n),PaddingRight=UDim.new(0,n)}) end
local function listv(g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,g or 6)}) end
local function tween(o,t,p) TweenService:Create(o,TweenInfo.new(t,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p):Play() end

local function mountHost()
    local sg = Instance.new("ScreenGui")
    sg.Name = "VoidHub_" .. tostring(math.random(1e6,9e6))
    sg.IgnoreGuiInset = true ; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.ResetOnSpawn = false ; sg.DisplayOrder = 10000
    local ok = pcall(function()
        if gethui then sg.Parent = gethui()
        elseif syn and syn.protect_gui then syn.protect_gui(sg); sg.Parent = CoreGui
        else sg.Parent = CoreGui end
    end)
    if not ok then sg.Parent = LP:WaitForChild("PlayerGui") end
    return sg
end

local function makeDraggable(handle, target)
    local dragging, start, origin
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true ; start = i.Position ; origin = target.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)
end

-- ============================================================
--   LIBRARY (flags store, window, elements, notify)
-- ============================================================
local Library = { _flags = {}, _elems = {}, _wins = {}, Theme = THEME }

function Library:SetFlag(f,v) self._flags[f]=v ; local e=self._elems[f]; if e and e.Set then pcall(e.Set,v,true) end end
function Library:GetFlag(f) return self._flags[f] end
function Library:ToggleFlag(f) self:SetFlag(f, not self._flags[f]) end
function Library:Dump()
    local o = {}
    for k,v in pairs(self._flags) do
        if typeof(v)=="Color3" then o[k]={"_c3",v.R,v.G,v.B}
        elseif typeof(v)=="EnumItem" then o[k]={"_enum",tostring(v.EnumType),v.Name}
        else o[k]=v end
    end
    return o
end
function Library:Apply(t)
    if type(t)~="table" then return end
    for k,v in pairs(t) do
        if type(v)=="table" and v[1]=="_c3" then self:SetFlag(k, Color3.new(v[2],v[3],v[4]))
        elseif type(v)=="table" and v[1]=="_enum" then
            local et = Enum[v[2]:match("Enum%.(.+)")] or Enum[v[2]]
            if et then self:SetFlag(k, et[v[3]]) end
        else self:SetFlag(k,v) end
    end
end

function Library:CreateWindow(opts)
    opts = opts or {}
    local host = mountHost()
    local size = opts.Size or Vector2.new(620,440)
    local root = new("Frame",{Parent=host,BackgroundColor3=THEME.Bg,
        Size=UDim2.fromOffset(size.X,size.Y),
        Position=UDim2.new(0.5,-size.X/2,0.5,-size.Y/2),
        BorderSizePixel=0,ClipsDescendants=true},{corner(UDim.new(0,10)),stroke(THEME.Stroke,1)})
    local topbar = new("Frame",{Parent=root,BackgroundColor3=THEME.Bg2,Size=UDim2.new(1,0,0,38),BorderSizePixel=0},{corner(UDim.new(0,10))})
    new("Frame",{Parent=topbar,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,Position=UDim2.new(0,0,1,-10),Size=UDim2.new(1,0,0,10)})
    new("TextLabel",{Parent=topbar,BackgroundTransparency=1,Position=UDim2.fromOffset(14,0),
        Size=UDim2.new(1,-120,1,0),Font=THEME.FontBold,TextSize=14,TextColor3=THEME.Text,
        TextXAlignment=Enum.TextXAlignment.Left,Text=opts.Title or "VoidHub"})
    new("TextLabel",{Parent=topbar,BackgroundTransparency=1,Position=UDim2.fromOffset(14,16),
        Size=UDim2.new(1,-120,0,16),Font=THEME.Font,TextSize=11,TextColor3=THEME.TextMuted,
        TextXAlignment=Enum.TextXAlignment.Left,Text=opts.Subtitle or ""})
    local close = new("TextButton",{Parent=topbar,BackgroundColor3=THEME.Danger,BorderSizePixel=0,
        Position=UDim2.new(1,-30,0,8),Size=UDim2.fromOffset(22,22),Text="×",Font=THEME.FontBold,
        TextColor3=THEME.Text,TextSize=16},{corner(UDim.new(1,0))})
    local mini = new("TextButton",{Parent=topbar,BackgroundColor3=THEME.Bg3,BorderSizePixel=0,
        Position=UDim2.new(1,-58,0,8),Size=UDim2.fromOffset(22,22),Text="–",Font=THEME.FontBold,
        TextColor3=THEME.Text,TextSize=16},{corner(UDim.new(1,0))})
    makeDraggable(topbar, root)

    local body = new("Frame",{Parent=root,BackgroundTransparency=1,Position=UDim2.fromOffset(0,38),Size=UDim2.new(1,0,1,-38)})
    local sidebar = new("Frame",{Parent=body,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,Size=UDim2.new(0,140,1,0)},
        {new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)}),pad(10)})
    local search = new("TextBox",{Parent=sidebar,BackgroundColor3=THEME.Bg3,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,26),Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,
        PlaceholderText="search…",PlaceholderColor3=THEME.TextMuted,ClearTextOnFocus=false,Text="",
        LayoutOrder=-1},{corner(UDim.new(0,6)),pad(6)})
    local pages = new("Frame",{Parent=body,BackgroundTransparency=1,Position=UDim2.fromOffset(140,0),Size=UDim2.new(1,-140,1,0)})

    local win = { Root = root, Host = host, _tabs = {}, _active = nil }

    function win:AddTab(t)
        local tab = { Name = t.Name }
        tab._btn = new("TextButton",{Parent=sidebar,BackgroundColor3=THEME.Bg3,BorderSizePixel=0,
            Size=UDim2.new(1,0,0,30),Font=THEME.Font,TextSize=12,TextColor3=THEME.TextMuted,
            Text="  "..t.Name,TextXAlignment=Enum.TextXAlignment.Left},{corner(UDim.new(0,6))})
        tab._page = new("ScrollingFrame",{Parent=pages,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),
            Visible=false,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=THEME.Accent,
            CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},{listv(8),pad(10)})
        tab._btn.MouseButton1Click:Connect(function()
            for _,tt in ipairs(win._tabs) do
                tt._page.Visible = false
                tt._btn.BackgroundColor3 = THEME.Bg3
                tt._btn.TextColor3 = THEME.TextMuted
            end
            tab._page.Visible = true
            tab._btn.BackgroundColor3 = THEME.AccentDim
            tab._btn.TextColor3 = THEME.Text
            win._active = tab
        end)

        function tab:AddSection(s)
            local sec = {}
            local box = new("Frame",{Parent=tab._page,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},
                {corner(UDim.new(0,8)),stroke(THEME.Stroke,1),pad(10),listv(6)})
            new("TextLabel",{Parent=box,BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),
                Font=THEME.FontBold,TextSize=12,TextColor3=THEME.Text,
                TextXAlignment=Enum.TextXAlignment.Left,Text=s.Name or "Section"})

            local function row(h) return new("Frame",{Parent=box,BackgroundColor3=THEME.Bg3,BorderSizePixel=0,
                Size=UDim2.new(1,0,0,h)},{corner(UDim.new(0,6)),pad(8)}) end

            function sec:AddToggle(o)
                local r = row(28)
                new("TextLabel",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(1,-40,1,0),
                    Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
                local pill = new("Frame",{Parent=r,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(32,16)},{corner(UDim.new(1,0))})
                local knob = new("Frame",{Parent=pill,BackgroundColor3=THEME.TextMuted,BorderSizePixel=0,
                    Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(12,12)},{corner(UDim.new(1,0))})
                local btn = new("TextButton",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text=""})
                local state = o.Default or false
                local function set(v,silent)
                    state = v and true or false
                    tween(pill,0.15,{BackgroundColor3=state and THEME.Accent or THEME.Bg2})
                    tween(knob,0.15,{Position=UDim2.fromOffset(state and 18 or 2,2),BackgroundColor3=state and Color3.new(1,1,1) or THEME.TextMuted})
                    if o.Flag then Library._flags[o.Flag] = state end
                    if o.Callback and not silent then task.spawn(o.Callback, state) end
                end
                btn.MouseButton1Click:Connect(function() set(not state) end)
                set(state,true)
                if o.Flag then Library._elems[o.Flag] = {Set=set} end
                return {Set=set}
            end

            function sec:AddButton(o)
                local r = row(28)
                local b = new("TextButton",{Parent=r,BackgroundColor3=THEME.AccentDim,BorderSizePixel=0,
                    Size=UDim2.new(1,0,1,0),Font=THEME.FontBold,TextSize=12,TextColor3=THEME.Text,
                    Text=o.Name or "",AutoButtonColor=false},{corner(UDim.new(0,4))})
                b.MouseEnter:Connect(function() tween(b,0.1,{BackgroundColor3=THEME.Accent}) end)
                b.MouseLeave:Connect(function() tween(b,0.1,{BackgroundColor3=THEME.AccentDim}) end)
                b.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
            end

            function sec:AddLabel(o)
                new("TextLabel",{Parent=box,BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),
                    Font=THEME.Font,TextSize=11,TextColor3=THEME.TextMuted,
                    TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
            end

            function sec:AddSlider(o)
                local r = row(44)
                new("TextLabel",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(1,-50,0,14),
                    Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
                local vl = new("TextLabel",{Parent=r,BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),
                    Position=UDim2.new(1,0,0,0),Size=UDim2.fromOffset(50,14),Font=THEME.FontBold,TextSize=12,
                    TextColor3=THEME.Accent,TextXAlignment=Enum.TextXAlignment.Right,Text=""})
                local bar = new("Frame",{Parent=r,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                    Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,6)},{corner(UDim.new(1,0))})
                local fill = new("Frame",{Parent=bar,BackgroundColor3=THEME.Accent,BorderSizePixel=0,Size=UDim2.new(0,0,1,0)},{corner(UDim.new(1,0))})
                local step = o.Step or 1 ; local mn,mx = o.Min or 0, o.Max or 100
                local v = o.Default or mn
                local function clamp(n) return math.clamp(math.floor((n-mn)/step+0.5)*step+mn, mn, mx) end
                local function set(n, silent)
                    v = clamp(n)
                    fill.Size = UDim2.new((v-mn)/(mx-mn),0,1,0)
                    vl.Text = (step<1) and string.format("%.2f",v) or tostring(v)
                    if o.Flag then Library._flags[o.Flag]=v end
                    if o.Callback and not silent then task.spawn(o.Callback,v) end
                end
                local drag=false
                bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true end end)
                UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
                UIS.InputChanged:Connect(function(i)
                    if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                        local rel = (i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
                        set(mn + rel*(mx-mn))
                    end
                end)
                set(v,true)
                if o.Flag then Library._elems[o.Flag]={Set=set} end
                return {Set=set}
            end

            function sec:AddDropdown(o)
                local r = row(30)
                local opts = o.Options or {} ; local v = o.Default
                new("TextLabel",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(0.5,0,1,0),
                    Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
                local disp = new("TextButton",{Parent=r,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.new(0.5,-6,0,22),
                    Font=THEME.Font,TextSize=11,TextColor3=THEME.Text,Text=tostring(v or "…"),AutoButtonColor=false},{corner(UDim.new(0,4)),pad(6)})
                local list = new("Frame",{Parent=box,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                    Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Visible=false,ClipsDescendants=true},
                    {corner(UDim.new(0,6)),pad(4),listv(2)})
                local function set(n,silent)
                    v=n ; disp.Text=tostring(n)
                    if o.Flag then Library._flags[o.Flag]=v end
                    if o.Callback and not silent then task.spawn(o.Callback,v) end
                end
                local function rebuild()
                    for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                    for _,it in ipairs(opts) do
                        local b = new("TextButton",{Parent=list,BackgroundColor3=THEME.Bg3,BorderSizePixel=0,
                            Size=UDim2.new(1,0,0,22),Font=THEME.Font,TextSize=11,TextColor3=THEME.Text,
                            Text=tostring(it),AutoButtonColor=false},{corner(UDim.new(0,4))})
                        b.MouseButton1Click:Connect(function() set(it) ; list.Visible=false end)
                    end
                end
                disp.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
                local function setOptions(n) opts=n or {} ; rebuild() end
                rebuild()
                if v == nil and opts[1] then set(opts[1],true) end
                if o.Flag then Library._elems[o.Flag]={Set=set,SetOptions=setOptions} end
                return {Set=set,SetOptions=setOptions}
            end

            function sec:AddKeybind(o)
                local r = row(28)
                new("TextLabel",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(1,-80,1,0),
                    Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
                local disp = new("TextButton",{Parent=r,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(80,20),
                    Font=THEME.FontBold,TextSize=11,TextColor3=THEME.Accent,Text="…",AutoButtonColor=false},{corner(UDim.new(0,4))})
                local key = o.Default ; local listening = false
                local function label(k) if not k then return "none" end if typeof(k)=="EnumItem" then return k.Name end return tostring(k) end
                local function set(k,silent) key=k ; disp.Text=label(k) ; if o.Flag then Library._flags[o.Flag]=k end end
                disp.MouseButton1Click:Connect(function() listening=true ; disp.Text="press…" end)
                UIS.InputBegan:Connect(function(i,gp)
                    if gp then return end
                    if listening then
                        if i.KeyCode ~= Enum.KeyCode.Unknown then set(i.KeyCode)
                        elseif i.UserInputType == Enum.UserInputType.MouseButton2 then set(Enum.UserInputType.MouseButton2)
                        elseif i.UserInputType == Enum.UserInputType.MouseButton1 then set(Enum.UserInputType.MouseButton1) end
                        listening = false ; return
                    end
                    if key and (i.KeyCode==key or i.UserInputType==key) and o.Callback then task.spawn(o.Callback) end
                end)
                set(key,true)
                if o.Flag then Library._elems[o.Flag]={Set=set} end
                return {Set=set}
            end

            function sec:AddColor(o)
                local r = row(28)
                new("TextLabel",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(1,-40,1,0),
                    Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
                local sw = new("TextButton",{Parent=r,BackgroundColor3=o.Default or Color3.new(1,1,1),BorderSizePixel=0,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(28,18),Text="",AutoButtonColor=false},
                    {corner(UDim.new(0,4)),stroke(THEME.Stroke,1)})
                local c = o.Default or Color3.new(1,1,1) ; local h = 0
                local function set(v,silent)
                    c=v ; sw.BackgroundColor3=v
                    if o.Flag then Library._flags[o.Flag]=v end
                    if o.Callback and not silent then task.spawn(o.Callback,v) end
                end
                sw.MouseButton1Click:Connect(function() h=(h+0.08)%1 ; set(Color3.fromHSV(h,0.8,1)) end)
                set(c,true)
                if o.Flag then Library._elems[o.Flag]={Set=set} end
                return {Set=set}
            end

            function sec:AddTextbox(o)
                local r = row(28)
                new("TextLabel",{Parent=r,BackgroundTransparency=1,Size=UDim2.new(0.4,0,1,0),
                    Font=THEME.Font,TextSize=12,TextColor3=THEME.Text,TextXAlignment=Enum.TextXAlignment.Left,Text=o.Name or ""})
                local tb = new("TextBox",{Parent=r,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.new(0.6,-6,0,22),
                    Font=THEME.Font,TextSize=11,TextColor3=THEME.Text,PlaceholderText=o.Placeholder or "",
                    PlaceholderColor3=THEME.TextMuted,ClearTextOnFocus=false,Text=o.Default or ""},{corner(UDim.new(0,4)),pad(6)})
                local function set(v,silent)
                    tb.Text = tostring(v or "")
                    if o.Flag then Library._flags[o.Flag]=tb.Text end
                    if o.Callback and not silent then task.spawn(o.Callback,tb.Text) end
                end
                tb.FocusLost:Connect(function() set(tb.Text) end)
                if o.Flag then Library._flags[o.Flag] = tb.Text ; Library._elems[o.Flag]={Set=set} end
                return {Set=set}
            end

            return sec
        end

        table.insert(win._tabs, tab)
        if #win._tabs == 1 then
            task.defer(function()
                tab._page.Visible = true
                tab._btn.BackgroundColor3 = THEME.AccentDim
                tab._btn.TextColor3 = THEME.Text
                win._active = tab
            end)
        end
        return tab
    end

    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        if win._active then
            for _,c in ipairs(win._active._page:GetChildren()) do
                if c:IsA("Frame") then
                    if q == "" then c.Visible = true
                    else
                        local hit = false
                        for _,d in ipairs(c:GetDescendants()) do
                            if d:IsA("TextLabel") and d.Text:lower():find(q,1,true) then hit=true break end
                        end
                        c.Visible = hit
                    end
                end
            end
        end
    end)

    close.MouseButton1Click:Connect(function() if _G.VoidHub and _G.VoidHub.Unload then _G.VoidHub.Unload() end end)
    local minimized = false
    mini.MouseButton1Click:Connect(function()
        minimized = not minimized
        tween(root,0.15,{Size = minimized and UDim2.fromOffset(size.X,38) or UDim2.fromOffset(size.X,size.Y)})
    end)

    local bind = opts.Keybind or Enum.KeyCode.RightShift
    UIS.InputBegan:Connect(function(i,gp) if gp then return end if i.KeyCode == bind then root.Visible = not root.Visible end end)

    function win:Destroy() host:Destroy() end
    table.insert(Library._wins, win)
    return win
end

function Library:Notify(o)
    if not self._notifyHost then
        self._notifyHost = mountHost()
        self._notifyBox = new("Frame",{Parent=self._notifyHost,BackgroundTransparency=1,
            AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-16),Size=UDim2.fromOffset(280,400)},
            {new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,
                VerticalAlignment=Enum.VerticalAlignment.Bottom,Padding=UDim.new(0,6)})})
    end
    local n = new("Frame",{Parent=self._notifyBox,BackgroundColor3=THEME.Bg2,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},
        {corner(UDim.new(0,8)),stroke(THEME.Accent,1),pad(10),listv(2)})
    new("TextLabel",{Parent=n,BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),
        Font=THEME.FontBold,TextSize=12,TextColor3=THEME.Accent,
        TextXAlignment=Enum.TextXAlignment.Left,Text=o.Title or "VoidHub"})
    new("TextLabel",{Parent=n,BackgroundTransparency=1,Size=UDim2.new(1,0,0,14),
        Font=THEME.Font,TextSize=11,TextColor3=THEME.Text,TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,Text=o.Text or "",AutomaticSize=Enum.AutomaticSize.Y})
    task.delay(o.Time or 4, function() tween(n,0.25,{BackgroundTransparency=1}) ; task.wait(0.3) ; n:Destroy() end)
end

-- ============================================================
--   CONFIG (JSON profiles on disk)
-- ============================================================
local Config = {}
local ROOT, PROFILES, LAST = "VoidHub", "VoidHub/profiles", "VoidHub/last.txt"
local hasFS  = (typeof(writefile)=="function") and (typeof(readfile)=="function") and (typeof(isfile)=="function")
local hasDir = (typeof(makefolder)=="function") and (typeof(isfolder)=="function") and (typeof(listfiles)=="function")
local function ensure()
    if not hasDir then return end
    if not isfolder(ROOT) then makefolder(ROOT) end
    if not isfolder(PROFILES) then makefolder(PROFILES) end
end
local function cpath(n) return PROFILES .. "/" .. n .. ".json" end
function Config.List()
    ensure() ; local o = {}
    if not hasDir then return o end
    for _,f in ipairs(listfiles(PROFILES)) do local n = f:match("([^/\\]+)%.json$") if n then table.insert(o,n) end end
    return o
end
function Config.Save(name, data)
    if not hasFS then return false end
    ensure()
    local ok, b = pcall(HttpService.JSONEncode, HttpService, data) ; if not ok then return false end
    writefile(cpath(name), b) ; writefile(LAST, name) ; return true
end
function Config.Load(name)
    if not hasFS or not isfile(cpath(name)) then return {} end
    local ok, d = pcall(HttpService.JSONDecode, HttpService, readfile(cpath(name)))
    if not ok then return {} end
    writefile(LAST, name) ; return d
end
function Config.Delete(name)
    if not hasFS then return end
    if typeof(delfile)=="function" and isfile(cpath(name)) then pcall(delfile, cpath(name)) end
end
function Config.GetLast() if not hasFS or not isfile(LAST) then return nil end return readfile(LAST) end

-- ============================================================
--   ESP
-- ============================================================
local Cam = Workspace.CurrentCamera
local ESPState = {
    on=false, box=true, name=true, health=true, dist=true, tracer=false, skel=false, chams=false,
    team=false, enemy=Color3.fromRGB(255,80,80), ally=Color3.fromRGB(80,200,255),
    maxDist=1500, tracerOrigin="Bottom",
}
local espPool = {}
local function mkDraw(c) local d=Drawing.new(c); d.Visible=false; return d end
local function ensureESP(p)
    if espPool[p] then return espPool[p] end
    local d = {Box=mkDraw("Square"),BoxOut=mkDraw("Square"),Name=mkDraw("Text"),Dist=mkDraw("Text"),
        Hp=mkDraw("Line"),HpBg=mkDraw("Line"),Tracer=mkDraw("Line"),Chams=nil,Skel={}}
    d.Box.Thickness=1 ; d.BoxOut.Thickness=3 ; d.BoxOut.Transparency=0.4
    d.Name.Center=true ; d.Name.Outline=true ; d.Name.Size=14 ; d.Name.Font=2
    d.Dist.Center=true ; d.Dist.Outline=true ; d.Dist.Size=12 ; d.Dist.Font=2
    d.Hp.Thickness=3 ; d.HpBg.Thickness=3 ; d.HpBg.Color=Color3.new(0,0,0) ; d.Tracer.Thickness=1
    espPool[p] = d ; return d
end
local function wipeESP(d)
    d.Box.Visible=false ; d.BoxOut.Visible=false ; d.Name.Visible=false ; d.Dist.Visible=false
    d.Hp.Visible=false ; d.HpBg.Visible=false ; d.Tracer.Visible=false
    for _,l in ipairs(d.Skel) do l.Visible=false end
    if d.Chams then d.Chams.Enabled=false end
end
local function destroyESP(d)
    for _,k in ipairs({"Box","BoxOut","Name","Dist","Hp","HpBg","Tracer"}) do d[k]:Remove() end
    for _,l in ipairs(d.Skel) do l:Remove() end
    if d.Chams then d.Chams:Destroy() end
end
Players.PlayerRemoving:Connect(function(p) if espPool[p] then destroyESP(espPool[p]) ; espPool[p]=nil end end)
local SKEL = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local function colorFor(p)
    if ESPState.team and p.Team==LP.Team and not p.Neutral then return ESPState.ally end
    return ESPState.enemy
end
local function espUpdate(p)
    local d = ensureESP(p)
    local ch=p.Character ; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    if not (ch and hrp and hum and hum.Health>0) then wipeESP(d) return end
    local r,on = Cam:WorldToViewportPoint(hrp.Position)
    if not (on and r.Z>0) then wipeESP(d) return end
    local dist=(Cam.CFrame.Position-hrp.Position).Magnitude
    if dist>ESPState.maxDist then wipeESP(d) return end
    local top=Cam:WorldToViewportPoint(hrp.Position+Vector3.new(0,3,0))
    local bot=Cam:WorldToViewportPoint(hrp.Position-Vector3.new(0,3,0))
    local h=math.abs(top.Y-bot.Y) ; local w=h*0.5
    local x=r.X-w/2 ; local y=top.Y ; local col=colorFor(p)
    if ESPState.box then d.Box.Size=Vector2.new(w,h) d.Box.Position=Vector2.new(x,y) d.Box.Color=col d.Box.Visible=true
        d.BoxOut.Size=d.Box.Size d.BoxOut.Position=d.Box.Position d.BoxOut.Color=Color3.new(0,0,0) d.BoxOut.Visible=true
    else d.Box.Visible=false d.BoxOut.Visible=false end
    if ESPState.name then d.Name.Text=p.DisplayName d.Name.Position=Vector2.new(r.X,y-16) d.Name.Color=col d.Name.Visible=true
    else d.Name.Visible=false end
    if ESPState.dist then d.Dist.Text=string.format("%dm",dist) d.Dist.Position=Vector2.new(r.X,y+h+2) d.Dist.Color=col d.Dist.Visible=true
    else d.Dist.Visible=false end
    if ESPState.health then
        local pct=math.clamp(hum.Health/hum.MaxHealth,0,1) ; local bx=x-6
        d.HpBg.From=Vector2.new(bx,y) d.HpBg.To=Vector2.new(bx,y+h) d.HpBg.Visible=true
        d.Hp.From=Vector2.new(bx,y+h) d.Hp.To=Vector2.new(bx,y+h-h*pct)
        d.Hp.Color=Color3.fromHSV(pct*0.33,1,1) d.Hp.Visible=true
    else d.Hp.Visible=false d.HpBg.Visible=false end
    if ESPState.tracer then
        local o
        if ESPState.tracerOrigin=="Top" then o=Vector2.new(Cam.ViewportSize.X/2,0)
        elseif ESPState.tracerOrigin=="Center" then o=Cam.ViewportSize/2
        elseif ESPState.tracerOrigin=="Mouse" then local m=LP:GetMouse() o=Vector2.new(m.X,m.Y)
        else o=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y) end
        d.Tracer.From=o d.Tracer.To=Vector2.new(r.X,y+h) d.Tracer.Color=col d.Tracer.Visible=true
    else d.Tracer.Visible=false end
    if ESPState.skel then
        for i,pair in ipairs(SKEL) do
            local a=ch:FindFirstChild(pair[1]) ; local b=ch:FindFirstChild(pair[2])
            local l=d.Skel[i] ; if not l then l=mkDraw("Line") l.Thickness=1 d.Skel[i]=l end
            if a and b then
                local pa,oa=Cam:WorldToViewportPoint(a.Position)
                local pb,ob=Cam:WorldToViewportPoint(b.Position)
                if oa and ob then l.From=Vector2.new(pa.X,pa.Y) l.To=Vector2.new(pb.X,pb.Y) l.Color=col l.Visible=true
                else l.Visible=false end
            else l.Visible=false end
        end
    else for _,l in ipairs(d.Skel) do l.Visible=false end end
    if ESPState.chams then
        if not d.Chams then d.Chams=Instance.new("Highlight") d.Chams.FillTransparency=0.6
            d.Chams.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop d.Chams.Parent=ch end
        d.Chams.Adornee=ch d.Chams.FillColor=col d.Chams.OutlineColor=col d.Chams.Enabled=true
    elseif d.Chams then d.Chams.Enabled=false end
end
local espConn
espConn = RunService.RenderStepped:Connect(function()
    if not ESPState.on then for _,d in pairs(espPool) do wipeESP(d) end return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP then local ok = pcall(espUpdate, p) ; if not ok and espPool[p] then wipeESP(espPool[p]) end end
    end
end)
local ESP = {}
function ESP.SetEnabled(v) ESPState.on=v end
function ESP.SetBox(v) ESPState.box=v end
function ESP.SetName(v) ESPState.name=v end
function ESP.SetHealth(v) ESPState.health=v end
function ESP.SetDistance(v) ESPState.dist=v end
function ESP.SetTracer(v) ESPState.tracer=v end
function ESP.SetSkeleton(v) ESPState.skel=v end
function ESP.SetChams(v) ESPState.chams=v end
function ESP.SetTeamCheck(v) ESPState.team=v end
function ESP.SetMaxDistance(v) ESPState.maxDist=v end
function ESP.SetEnemyColor(c) ESPState.enemy=c end
function ESP.SetAllyColor(c) ESPState.ally=c end
function ESP.SetTracerOrigin(s) ESPState.tracerOrigin=s end
function ESP.Destroy() if espConn then espConn:Disconnect() end for _,d in pairs(espPool) do destroyESP(d) end espPool={} end

-- ============================================================
--   AIM + TRIGGER
-- ============================================================
local Mouse = LP:GetMouse()
local AimS = {on=false,trig=false,trigDelay=50,part="Head",fov=120,smooth=30,visOnly=true,team=true,drawFov=false,
    bind=Enum.UserInputType.MouseButton2,_down=false}
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness=1 ; fovCircle.NumSides=64 ; fovCircle.Color=Color3.fromRGB(140,90,255)
fovCircle.Transparency=0.7 ; fovCircle.Visible=false ; fovCircle.Filled=false
local function aimValid(p)
    if p == LP then return false end
    local ch=p.Character ; local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    if not (hum and hum.Health>0) then return false end
    if AimS.team and p.Team==LP.Team and not p.Neutral then return false end
    local part = ch:FindFirstChild(AimS.part) or ch:FindFirstChild("HumanoidRootPart")
    if not part then return false end
    if AimS.visOnly then
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {LP.Character, ch}
        if Workspace:Raycast(Cam.CFrame.Position, part.Position - Cam.CFrame.Position, rp) then return false end
    end
    return true, part
end
local function aimBest()
    local pick, closest = nil, AimS.fov
    for _,p in ipairs(Players:GetPlayers()) do
        local ok, part = aimValid(p)
        if ok then
            local sp = Cam:WorldToViewportPoint(part.Position)
            local d = (Vector2.new(sp.X,sp.Y) - UIS:GetMouseLocation()).Magnitude
            if d < closest then closest = d ; pick = part end
        end
    end
    return pick
end
RunService.RenderStepped:Connect(function()
    if AimS.drawFov then fovCircle.Position=UIS:GetMouseLocation() fovCircle.Radius=AimS.fov fovCircle.Visible=true
    else fovCircle.Visible=false end
    if not (AimS.on and AimS._down) then return end
    local part = aimBest() ; if not part then return end
    local sp = Cam:WorldToViewportPoint(part.Position)
    local mp = UIS:GetMouseLocation()
    local a = math.clamp(1 - AimS.smooth/100, 0.02, 1)
    pcall(function() mousemoverel((sp.X - mp.X)*a, (sp.Y - mp.Y)*a) end)
end)
UIS.InputBegan:Connect(function(i,gp) if gp then return end if i.UserInputType==AimS.bind or i.KeyCode==AimS.bind then AimS._down=true end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==AimS.bind or i.KeyCode==AimS.bind then AimS._down=false end end)
local trigLast = 0
RunService.Heartbeat:Connect(function()
    if not AimS.trig then return end
    local now = tick()*1000 ; if now - trigLast < AimS.trigDelay then return end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LP.Character}
    local u = Cam:ScreenPointToRay(Mouse.X, Mouse.Y, 0)
    local r = Workspace:Raycast(u.Origin, u.Direction*1000, rp)
    if not r then return end
    local m = r.Instance:FindFirstAncestorOfClass("Model")
    local plr = m and Players:GetPlayerFromCharacter(m)
    if plr and plr ~= LP then
        if AimS.team and plr.Team==LP.Team and not plr.Neutral then return end
        trigLast = now
        pcall(function() mouse1press() task.wait(0.03) mouse1release() end)
    end
end)
local Aim = {}
function Aim.SetEnabled(v) AimS.on=v end
function Aim.SetTargetPart(s) AimS.part=s end
function Aim.SetFOV(n) AimS.fov=n end
function Aim.SetSmoothness(n) AimS.smooth=n end
function Aim.SetVisibleOnly(v) AimS.visOnly=v end
function Aim.SetTeamCheck(v) AimS.team=v end
function Aim.SetDrawFOV(v) AimS.drawFov=v end
function Aim.SetBind(k) AimS.bind=k end
function Aim.SetTriggerEnabled(v) AimS.trig=v end
function Aim.SetTriggerDelay(n) AimS.trigDelay=n end
function Aim.Destroy() fovCircle:Remove() end

-- ============================================================
--   MOVEMENT
-- ============================================================
local MoveS = {ws=16,jp=50,infJump=false,fly=false,flySpeed=60,_flyBV=nil,_flyBG=nil,_noclip=nil,_fly=nil}
local function hum() local c=LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c=LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function applyHum() local h=hum() if h then h.WalkSpeed=MoveS.ws h.JumpPower=MoveS.jp h.UseJumpPower=true end end
LP.CharacterAdded:Connect(function(ch) ch:WaitForChild("Humanoid") task.wait(0.1) applyHum() end)
UIS.JumpRequest:Connect(function() if MoveS.infJump then local h=hum() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
local Movement = {}
function Movement.SetWalkSpeed(v) MoveS.ws=v applyHum() end
function Movement.SetJumpPower(v) MoveS.jp=v applyHum() end
function Movement.SetGravity(v) Workspace.Gravity=v end
function Movement.SetInfJump(v) MoveS.infJump=v end
function Movement.SetNoclip(v)
    if MoveS._noclip then MoveS._noclip:Disconnect() MoveS._noclip=nil end
    if v then
        MoveS._noclip = RunService.Stepped:Connect(function()
            local ch=LP.Character ; if not ch then return end
            for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end
        end)
    end
end
function Movement.SetFly(v)
    MoveS.fly=v
    if MoveS._flyBV then MoveS._flyBV:Destroy() MoveS._flyBV=nil end
    if MoveS._flyBG then MoveS._flyBG:Destroy() MoveS._flyBG=nil end
    if MoveS._fly then MoveS._fly:Disconnect() MoveS._fly=nil end
    local h=hum() if h then h.PlatformStand=false end
    if not v then return end
    local root=hrp() ; if not root then return end
    local bv=Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge) bv.Velocity=Vector3.zero bv.Parent=root
    local bg=Instance.new("BodyGyro") bg.MaxTorque=Vector3.new(math.huge,math.huge,math.huge) bg.P=1e4 bg.CFrame=root.CFrame bg.Parent=root
    MoveS._flyBV, MoveS._flyBG = bv, bg
    MoveS._fly = RunService.RenderStepped:Connect(function()
        if not MoveS._flyBV then return end
        local cam=Workspace.CurrentCamera ; local dir=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.new(0,1,0) end
        if dir.Magnitude>0 then dir=dir.Unit end
        MoveS._flyBV.Velocity = dir * MoveS.flySpeed
        MoveS._flyBG.CFrame = cam.CFrame
        local h=hum() if h then h.PlatformStand=true end
    end)
end
function Movement.SetFlySpeed(v) MoveS.flySpeed=v end
function Movement.Destroy() Movement.SetFly(false) Movement.SetNoclip(false) end

-- ============================================================
--   WORLD
-- ============================================================
local saved = {Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,
    FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,GlobalShadows=Lighting.GlobalShadows}
local WorldS = {fb=false,nofog=false,low=false}
local World = {}
function World.SetFullbright(v)
    WorldS.fb=v
    if v then Lighting.Ambient=Color3.new(1,1,1) Lighting.OutdoorAmbient=Color3.new(1,1,1) Lighting.Brightness=2 Lighting.GlobalShadows=false Lighting.FogEnd=1e9
    else Lighting.Ambient=saved.Ambient Lighting.OutdoorAmbient=saved.OutdoorAmbient Lighting.Brightness=saved.Brightness Lighting.GlobalShadows=saved.GlobalShadows Lighting.FogEnd=saved.FogEnd end
end
function World.SetNoFog(v) WorldS.nofog=v if v then Lighting.FogEnd=1e9 Lighting.FogStart=1e9 else Lighting.FogEnd=saved.FogEnd Lighting.FogStart=saved.FogStart end end
function World.SetLowGfx(v)
    WorldS.low=v
    for _,d in ipairs(game:GetDescendants()) do
        if v then
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then d.Enabled=false
            elseif d:IsA("Texture") or d:IsA("Decal") then d.Transparency=1
            elseif d:IsA("BasePart") then d.Material=Enum.Material.SmoothPlastic end
        end
    end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel["Level01"] end)
end
function World.SetFOV(v) Workspace.CurrentCamera.FieldOfView=v end
function World.SetTimeOfDay(v) Lighting.ClockTime=v end
function World.Destroy() World.SetFullbright(false) World.SetNoFog(false) end

-- ============================================================
--   MISC
-- ============================================================
local MiscS = {_afk=nil,_lastPos=nil}
local Misc = {}
function Misc.SetAntiAfk(v)
    if MiscS._afk then MiscS._afk:Disconnect() MiscS._afk=nil end
    if v then MiscS._afk = LP.Idled:Connect(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end
end
function Misc.Rejoin() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
function Misc.ServerHop()
    local req = (syn and syn.request) or (http and http.request) or request
    if not req then return end
    local ok, r = pcall(function() return req({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100",Method="GET"}) end)
    if not ok or not r or r.StatusCode ~= 200 then return end
    local data = HttpService:JSONDecode(r.Body)
    for _,s in ipairs(data.data or {}) do
        if s.id ~= game.JobId and s.playing < s.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP) ; return
        end
    end
end
function Misc.CopyJobId()
    if setclipboard then pcall(setclipboard, game.JobId)
    elseif toclipboard then pcall(toclipboard, game.JobId) end
end
function Misc.ReturnCharacter()
    local r=hrp() if r and MiscS._lastPos then r.CFrame=MiscS._lastPos end
end
function Misc.Destroy() if MiscS._afk then MiscS._afk:Disconnect() end end

-- ============================================================
--   VOID (TP + KICK — cascaded, rewind, hotkeys)
-- ============================================================
local VoidS = {busy=false,history={},maxHistory=8,tpSpeed=1,kickPower=9e8,kickTicks=40,autoReturn=true}

local function voidSnap()
    local ch=LP.Character ; local h=hum() ; local r=hrp()
    if not (ch and h and r) then return nil end
    return {char=ch,hum=h,root=r,cf=r.CFrame,ws=h.WalkSpeed,jp=h.JumpPower,plat=h.PlatformStand}
end
local function stillValid(s) return s and s.char and s.char.Parent and s.root and s.root.Parent and s.hum and s.hum.Health>0 end
local function pushHist(cf)
    table.insert(VoidS.history, cf)
    if #VoidS.history > VoidS.maxHistory then table.remove(VoidS.history, 1) end
end
local function cfOf(t)
    if typeof(t)=="CFrame" then return t end
    if typeof(t)=="Vector3" then return CFrame.new(t) end
    if typeof(t)=="Instance" and t:IsA("Player") then local c=t.Character local r=c and c:FindFirstChild("HumanoidRootPart") return r and r.CFrame end
    if typeof(t)=="Instance" and t:IsA("BasePart") then return t.CFrame end
end
local Void = {}
function Void.Teleport(target, opts)
    opts = opts or {}
    if VoidS.busy then return false, "busy" end
    VoidS.busy = true
    local s = voidSnap() ; if not s then VoidS.busy=false return false,"no char" end
    pushHist(s.cf)
    local dest = cfOf(target) ; if not dest then VoidS.busy=false return false,"bad target" end
    if opts.offset then dest = dest * CFrame.new(opts.offset) end
    if opts.predict and typeof(target)=="Instance" and target:IsA("Player") then
        local tr = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tr then dest = dest + tr.AssemblyLinearVelocity * (opts.predict or 0.2) end
    end
    s.hum.PlatformStand=true ; s.hum.AutoRotate=false
    s.root.AssemblyLinearVelocity=Vector3.zero ; s.root.AssemblyAngularVelocity=Vector3.zero
    local start, goal = s.cf.Position, dest.Position
    local steps = math.max(1, math.ceil((goal-start).Magnitude / 180))
    local stepDelay = VoidS.tpSpeed / steps
    for i = 1, steps do
        if not stillValid(s) then VoidS.busy=false return false,"char gone" end
        local a = i / steps
        local pos = start:Lerp(goal, a)
        s.root.CFrame = CFrame.new(pos, pos + dest.LookVector)
        s.root.AssemblyLinearVelocity = Vector3.zero
        task.wait(stepDelay)
    end
    s.root.CFrame = dest ; s.root.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.05)
    s.hum.PlatformStand=false ; s.hum.AutoRotate=true
    VoidS.busy = false
    return true
end
function Void.Rewind() local cf = table.remove(VoidS.history) if not cf then return false,"empty" end return Void.Teleport(cf) end
function Void.ToPlayer(name, opts)
    local plr
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Name:lower():sub(1,#name)==name:lower() then plr = p ; break end
    end
    if not plr then return false,"no player" end
    return Void.Teleport(plr, opts)
end
local function targetAlive(p)
    local ch=p.Character ; local h=ch and ch:FindFirstChildOfClass("Humanoid") ; local r=ch and ch:FindFirstChild("HumanoidRootPart")
    return (h and h.Health>0 and r) and h, r
end
local function mv_velocity(p, dead)
    local h,r = targetAlive(p) ; if not r then return end
    local me = hrp() ; if not me then return end
    local bv = Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
    bv.Velocity=Vector3.new(0,-VoidS.kickPower,0) bv.Parent=r
    for i=1, VoidS.kickTicks do
        if dead[1] then break end
        local h2,r2 = targetAlive(p) ; if not r2 then break end
        r2.AssemblyLinearVelocity = Vector3.new(0,-VoidS.kickPower,0)
        r2.CFrame = r2.CFrame - Vector3.new(0, VoidS.kickPower*0.001, 0)
        task.wait()
    end
    pcall(function() bv:Destroy() end)
end
local function mv_touch(p, dead)
    local h,r = targetAlive(p) ; if not r then return end
    local me = hrp() ; if not me then return end
    local ch = LP.Character ; local cc = {}
    if ch then for _,b in ipairs(ch:GetDescendants()) do if b:IsA("BasePart") then cc[b]=b.CanCollide ; b.CanCollide=false end end end
    for i=1, VoidS.kickTicks do
        if dead[1] then break end
        local h2,r2 = targetAlive(p) ; if not r2 then break end
        me.CFrame = r2.CFrame
        r2.AssemblyLinearVelocity = Vector3.new(0,-VoidS.kickPower,0)
        task.wait()
        me.CFrame = r2.CFrame * CFrame.new(0, -VoidS.kickPower*0.0005, 0)
        task.wait()
    end
    for b,v in pairs(cc) do if b and b.Parent then b.CanCollide=v end end
end
local function mv_spam(p, dead)
    for i=1, VoidS.kickTicks*2 do
        if dead[1] then break end
        local h2,r2 = targetAlive(p) ; if not r2 then break end
        r2.AssemblyLinearVelocity = Vector3.new(0,-VoidS.kickPower,0)
        r2.AssemblyAngularVelocity = Vector3.new(VoidS.kickPower,0,VoidS.kickPower)
        task.wait()
    end
end
local function mv_weld(p, dead)
    local h,r = targetAlive(p) ; if not r then return end
    local me = hrp() ; if not me then return end
    local w = Instance.new("WeldConstraint") w.Part0=me w.Part1=r w.Parent=me
    for i=1, math.ceil(VoidS.kickTicks/2) do
        if dead[1] then break end
        me.CFrame = CFrame.new(0,-1e6,0) * CFrame.Angles(math.random(), math.random(), math.random())
        task.wait()
    end
    pcall(function() w:Destroy() end)
end
function Void.Kick(target)
    if typeof(target) == "string" then
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Name:lower():sub(1,#target)==target:lower() then target = p ; break end
        end
    end
    if typeof(target) ~= "Instance" or not target:IsA("Player") or target == LP then return false, "bad" end
    if VoidS.busy then return false, "busy" end
    VoidS.busy = true
    local s = voidSnap() ; if not s then VoidS.busy=false return false,"no char" end
    pushHist(s.cf)
    local dead = {false}
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < 6 do
            local h,r = targetAlive(target) ; if not (h and r) then dead[1]=true break end
            task.wait(0.05)
        end
        dead[1]=true
    end)
    s.hum.PlatformStand=true ; s.hum.AutoRotate=false
    for _, m in ipairs({mv_velocity, mv_touch, mv_spam, mv_weld}) do
        if dead[1] then break end
        pcall(m, target, dead)
    end
    if VoidS.autoReturn then
        task.wait(0.1)
        if stillValid(s) then s.hum.PlatformStand=false s.hum.AutoRotate=true s.root.CFrame=s.cf s.root.AssemblyLinearVelocity=Vector3.zero end
    end
    VoidS.busy = false
    return dead[1]
end
function Void.SetTpSpeed(v) VoidS.tpSpeed = math.max(0.05, v) end
function Void.SetKickPower(v) VoidS.kickPower = v end
function Void.SetKickTicks(v) VoidS.kickTicks = v end
function Void.SetAutoReturn(v) VoidS.autoReturn = v end
function Void.SetMaxHistory(v) VoidS.maxHistory = math.max(1, v) end
function Void.Destroy() VoidS.busy=false VoidS.history={} end

-- ============================================================
--   WINDOW + TABS WIRING
-- ============================================================
local Window = Library:CreateWindow({Title="VoidHub", Subtitle="v"..VERSION.." · "..game.Name,
    Keybind=Enum.KeyCode.RightShift, Size=Vector2.new(620,440)})

local TabPlayer = Window:AddTab({Name="Player"})
local TabCombat = Window:AddTab({Name="Combat"})
local TabVisual = Window:AddTab({Name="Visual"})
local TabWorld  = Window:AddTab({Name="World"})
local TabVoid   = Window:AddTab({Name="Void"})
local TabMisc   = Window:AddTab({Name="Misc"})
local TabConfig = Window:AddTab({Name="Config"})

do
    local s = TabPlayer:AddSection({Name="Movement"})
    s:AddSlider({Flag="WalkSpeed",Name="Walk Speed",Min=16,Max=500,Default=16,Callback=Movement.SetWalkSpeed})
    s:AddSlider({Flag="JumpPower",Name="Jump Power",Min=50,Max=500,Default=50,Callback=Movement.SetJumpPower})
    s:AddSlider({Flag="Gravity",Name="Gravity",Min=0,Max=400,Default=196,Callback=Movement.SetGravity})
    s:AddToggle({Flag="InfJump",Name="Infinite Jump",Callback=Movement.SetInfJump})
    s:AddToggle({Flag="NoClip",Name="Noclip",Callback=Movement.SetNoclip})
    s:AddToggle({Flag="Fly",Name="Fly",Callback=Movement.SetFly})
    s:AddSlider({Flag="FlySpeed",Name="Fly Speed",Min=10,Max=300,Default=60,Callback=Movement.SetFlySpeed})
    s:AddKeybind({Flag="FlyBind",Name="Fly Toggle",Default=Enum.KeyCode.F,Callback=function() Library:ToggleFlag("Fly") end})
end

do
    local s = TabCombat:AddSection({Name="Aim Assist"})
    s:AddToggle({Flag="AimEnabled",Name="Enabled",Callback=Aim.SetEnabled})
    s:AddDropdown({Flag="AimTarget",Name="Target Part",Default="Head",Options={"Head","HumanoidRootPart","Torso"},Callback=Aim.SetTargetPart})
    s:AddSlider({Flag="AimFOV",Name="FOV",Min=10,Max=500,Default=120,Callback=Aim.SetFOV})
    s:AddSlider({Flag="AimSmooth",Name="Smoothness",Min=0,Max=100,Default=30,Callback=Aim.SetSmoothness})
    s:AddToggle({Flag="AimVis",Name="Visible Only",Default=true,Callback=Aim.SetVisibleOnly})
    s:AddToggle({Flag="AimTeam",Name="Team Check",Default=true,Callback=Aim.SetTeamCheck})
    s:AddToggle({Flag="AimDrawFOV",Name="Draw FOV",Callback=Aim.SetDrawFOV})
    s:AddKeybind({Flag="AimBind",Name="Hold Key",Default=Enum.UserInputType.MouseButton2,Callback=Aim.SetBind})
    local t = TabCombat:AddSection({Name="Triggerbot"})
    t:AddToggle({Flag="TrigEnabled",Name="Enabled",Callback=Aim.SetTriggerEnabled})
    t:AddSlider({Flag="TrigDelay",Name="Delay (ms)",Min=0,Max=500,Default=50,Callback=Aim.SetTriggerDelay})
end

do
    local s = TabVisual:AddSection({Name="ESP"})
    s:AddToggle({Flag="EspEnabled",Name="Enabled",Callback=ESP.SetEnabled})
    s:AddToggle({Flag="EspBox",Name="Box",Default=true,Callback=ESP.SetBox})
    s:AddToggle({Flag="EspName",Name="Name",Default=true,Callback=ESP.SetName})
    s:AddToggle({Flag="EspHealth",Name="Health Bar",Default=true,Callback=ESP.SetHealth})
    s:AddToggle({Flag="EspDistance",Name="Distance",Default=true,Callback=ESP.SetDistance})
    s:AddToggle({Flag="EspTracer",Name="Tracer",Callback=ESP.SetTracer})
    s:AddToggle({Flag="EspSkeleton",Name="Skeleton",Callback=ESP.SetSkeleton})
    s:AddToggle({Flag="EspChams",Name="Chams",Callback=ESP.SetChams})
    s:AddToggle({Flag="EspTeam",Name="Team Check",Callback=ESP.SetTeamCheck})
    s:AddSlider({Flag="EspMaxDist",Name="Max Distance",Min=50,Max=5000,Default=1500,Step=10,Callback=ESP.SetMaxDistance})
    s:AddColor({Flag="EspEnemy",Name="Enemy Color",Default=Color3.fromRGB(255,80,80),Callback=ESP.SetEnemyColor})
    s:AddColor({Flag="EspAlly",Name="Ally Color",Default=Color3.fromRGB(80,200,255),Callback=ESP.SetAllyColor})
    s:AddDropdown({Flag="EspTracerFrom",Name="Tracer Origin",Default="Bottom",Options={"Bottom","Top","Mouse","Center"},Callback=ESP.SetTracerOrigin})
end

do
    local s = TabWorld:AddSection({Name="Rendering"})
    s:AddToggle({Flag="Fullbright",Name="Fullbright",Callback=World.SetFullbright})
    s:AddToggle({Flag="LowGfx",Name="Low Graphics",Callback=World.SetLowGfx})
    s:AddToggle({Flag="NoFog",Name="No Fog",Callback=World.SetNoFog})
    s:AddSlider({Flag="FieldOfView",Name="FOV",Min=40,Max=120,Default=70,Callback=World.SetFOV})
    s:AddSlider({Flag="TimeOfDay",Name="Time of Day",Min=0,Max=24,Default=14,Callback=World.SetTimeOfDay})
end

do
    local function names()
        local o = {}
        for _,p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(o, p.Name) end end
        return o
    end
    local tp = TabVoid:AddSection({Name="Void TP"})
    local tpTarget = tp:AddDropdown({Flag="VoidTpTarget",Name="Target",Options=names()})
    tp:AddButton({Name="Refresh Players", Callback=function() tpTarget.SetOptions(names()) end})
    tp:AddSlider({Flag="VoidTpSpeed",Name="TP Speed (s)",Min=0.05,Max=3,Step=0.05,Default=1,Callback=Void.SetTpSpeed})
    tp:AddSlider({Flag="VoidTpHistory",Name="Rewind History",Min=1,Max=32,Default=8,Callback=Void.SetMaxHistory})
    tp:AddButton({Name="Teleport to Target", Callback=function()
        local n = Library:GetFlag("VoidTpTarget") ; if not n then return end
        local ok, err = Void.ToPlayer(n, {predict=0.15, offset=Vector3.new(0,2,0)})
        Library:Notify({Title="VoidTP",Text=ok and ("→ "..n) or ("fail: "..tostring(err)),Time=3})
    end})
    tp:AddButton({Name="Rewind (undo last TP)", Callback=function()
        local ok, err = Void.Rewind()
        Library:Notify({Title="VoidTP",Text=ok and "rewound" or ("fail: "..tostring(err)),Time=3})
    end})
    tp:AddKeybind({Flag="VoidTpBind",Name="TP Hotkey",Default=Enum.KeyCode.T,Callback=function()
        local n = Library:GetFlag("VoidTpTarget") ; if n then Void.ToPlayer(n,{predict=0.15,offset=Vector3.new(0,2,0)}) end
    end})

    local kk = TabVoid:AddSection({Name="Void Kick"})
    local kkTarget = kk:AddDropdown({Flag="VoidKickTarget",Name="Target",Options=names()})
    kk:AddButton({Name="Refresh Players", Callback=function() kkTarget.SetOptions(names()) end})
    kk:AddSlider({Flag="VoidKickPower",Name="Power",Min=1e6,Max=1e9,Step=1e6,Default=9e8,Callback=Void.SetKickPower})
    kk:AddSlider({Flag="VoidKickTicks",Name="Ticks",Min=10,Max=200,Default=40,Callback=Void.SetKickTicks})
    kk:AddToggle({Flag="VoidKickReturn",Name="Auto-Return Self",Default=true,Callback=Void.SetAutoReturn})
    kk:AddButton({Name="Void Kick Target", Callback=function()
        local n = Library:GetFlag("VoidKickTarget") ; if not n then return end
        task.spawn(function()
            local ok = Void.Kick(n)
            Library:Notify({Title="VoidKick",Text=ok and ("killed "..n) or ("miss: "..n),Time=3})
        end)
    end})
    kk:AddKeybind({Flag="VoidKickBind",Name="Kick Hotkey",Default=Enum.KeyCode.K,Callback=function()
        local n = Library:GetFlag("VoidKickTarget") ; if n then task.spawn(Void.Kick, n) end
    end})

    Players.PlayerAdded:Connect(function() task.wait(0.5) tpTarget.SetOptions(names()) kkTarget.SetOptions(names()) end)
    Players.PlayerRemoving:Connect(function() task.wait(0.5) tpTarget.SetOptions(names()) kkTarget.SetOptions(names()) end)
end

do
    local s = TabMisc:AddSection({Name="Server"})
    s:AddToggle({Flag="AntiAfk",Name="Anti-AFK",Callback=Misc.SetAntiAfk})
    s:AddButton({Name="Rejoin",Callback=Misc.Rejoin})
    s:AddButton({Name="Server Hop",Callback=Misc.ServerHop})
    s:AddButton({Name="Copy Server JobId",Callback=Misc.CopyJobId})
    local h = TabMisc:AddSection({Name="Hub"})
    h:AddButton({Name="Unload",Callback=function() if _G.VoidHub then _G.VoidHub.Unload() end end})
    h:AddLabel({Name="Build: "..VERSION})
    h:AddLabel({Name="User: "..LP.Name})
end

do
    local s = TabConfig:AddSection({Name="Profiles"})
    s:AddTextbox({Flag="ConfigName",Name="Name",Default="default",Placeholder="profile"})
    s:AddButton({Name="Save",Callback=function() Config.Save(Library:GetFlag("ConfigName"), Library:Dump()) end})
    s:AddButton({Name="Load",Callback=function() Library:Apply(Config.Load(Library:GetFlag("ConfigName"))) end})
    s:AddButton({Name="Delete",Callback=function() Config.Delete(Library:GetFlag("ConfigName")) end})
    s:AddDropdown({Flag="ConfigList",Name="Profiles",Options=Config.List(),Callback=function(v) Library:SetFlag("ConfigName",v) end})
    s:AddToggle({Flag="AutoLoad",Name="Autoload on Join"})
end

-- ============================================================
--   UNLOAD + GLOBAL HANDLE
-- ============================================================
local Hub = { Version = VERSION, Library = Library, _dead = false }
_G.VoidHub = Hub
function Hub.Unload()
    if Hub._dead then return end
    Hub._dead = true
    pcall(ESP.Destroy) ; pcall(Aim.Destroy) ; pcall(Movement.Destroy)
    pcall(World.Destroy) ; pcall(Misc.Destroy) ; pcall(Void.Destroy)
    pcall(function() Window:Destroy() end)
    _G.VoidHub = nil
end

task.defer(function()
    local last = Config.GetLast()
    if last and Library:GetFlag("AutoLoad") then Library:Apply(Config.Load(last)) end
end)

Library:Notify({Title="VoidHub "..VERSION, Text="loaded — RightShift toggles UI", Time=5})

return Hub
