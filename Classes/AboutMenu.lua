AboutMenu = AboutMenu or class()
function AboutMenu:init()
	local EMenu = BLE.Menu
	ItemExt:add_funcs(self, EMenu:make_page("About", nil, {align_method = "normal", items_size = 16, scrollbar = false, auto_align=false}))
    local page = self:getmenu()
    local logo_size = 256 * 0.75
    local transparent = Color(0, 0, 0, 0)
    local contributors = {
        {"Ontrigger", "Developing the editor further"},
        {"Xeletron", "Developing the editor further"},
        {"soosh", "Editor icons, UI tweaks and QoL additions"},
        {"Walrus", "Helping development from the start, providing informaiton on PD2 mapping"},
        {"Rex", "Helping developing the editor, wiki documentation, 3D models for spawn elements"},
        {"Mako", "Maintaining the editor package data"},
        {"Cupcake", "Creating the original tutorial series"},
        {"Quackertree", "Feedback and helping beginners"},
        {"TheRealDannyyy", nil},
        {"Matthelzor", nil},
        {"Sora", nil},
        {"Whurrhurr", nil},
        {"MiamiCenterPL", nil},
        {"test1", nil},
        {"Cpone", nil},
        {"kythyria", nil},
        {"Hoppip", nil},
        {"RedFlame", nil},
        {"Javgarag", nil}
    }
    local links = {
        {"GitHub", "https://github.com/Luffyyy/BeardLib-Editor"},
        {"MWS Discord", "https://discord.gg/Eear4JW"},
        {"PAYDAY Maps Discord", "https://discord.gg/fn62qaq"},
        {"ModWorkshop", "https://modworkshop.net/mod/16837"},
        {"Feedback", "https://github.com/Luffyyy/BeardLib-Editor/issues"}
    }
    local guides = {
        {"BeardLib Wiki", "https://luffyyy.gitbook.io/beardlib"},
        {"BeardLib Editor Wiki", "https://wiki.modworkshop.net/books/beardlib-editor-tutorials"},
        {"PAYDAY Maps Guides", "https://wiki.paydaymaps.net/payday2"},
        {"Cupcake's Tutorial Videos (Outdated but still useful)", "https://www.youtube.com/playlist?list=PLRSASA7UrjTsX1WWG6kStRTK51DKSEDPn"},
        {"nyancatec's Tutorial Video", "https://www.youtube.com/watch?v=r1DpG2NDAts"}
    }

	local logo = page:Image({
		name = "Logo",
		icon_w = logo_size,
		icon_h = logo_size,
        w = logo_size,
        h = logo_size,
        position = {page:CenterX() - logo_size * 0.5, 0},
		offset = 0,
		texture = "textures/editor_logo"
	})
    local credits_panel = page:pan("Credits", {
        w = logo:X(),
        h = page:H() - 60,
        position = {0, 30},
        offset = {0, 0},
        full_bg_color = transparent,
        scrollbar = true,
        scroll_width = 4,
        scroll_color = Color.white:with_alpha(0.1),
        auto_height = false
    })
    local links_panel = page:pan("Links", {
        w = (page:W() - credits_panel:W()) / 3,
        h = page:H() - logo_size,
        position = {logo:Left()+ 8, logo:Bottom()},
        offset = {0, 0},
        full_bg_color = transparent,
        border_right = true,
        border_size = 1,
        border_color = Color.white
    })
    local guides_panel = page:pan("Guides", {
        w = page:W() - credits_panel:W() - links_panel:W(),
        h = page:H() - logo_size,
        position = {links_panel:Right() + 8, links_panel:Top()},
        offset = {0, 0},
        full_bg_color = transparent
    })

    local function text(text, panel, opt) 
        if not panel then
            log("[BeardLib Editor] ERROR: No parent panel set for text: '" .. text .. "'")
            return
        end
        return panel:divider(text, table.merge({color = false, text = text, offset = {0, 0}}, opt)) 
    end
    local function link_button(text, url, panel)
        if not panel then
            log("[BeardLib Editor] ERROR: No parent panel set for button: '" .. text .. "'")
            return
        end
        local btn = panel:button(text, SimpleClbk(os.execute, 'start "" "'..url..'"'), {text = name, size_by_text = true, help = url})
        btn:SetText(text) -- Removes the auto spacing on upper-case letters resulting in weird gaps like "Git Hub" instead of "GitHub".
        return btn 
    end

    -- credits panel
    text("Created by Luffy and Simon W", credits_panel, {size = 24})
    text("Thanks to the contributors:", credits_panel)
    for _, v in ipairs(contributors) do
        local name = v[1]
        text(name, credits_panel)
        if v[2] then
            text(v[2], credits_panel, {enabled_alpha = 0.75, offset = {20, -4}})
        end
    end
    text("And everyone else who helped!", credits_panel, {offset = {0, 18}})

    -- links panel
    text("Links:", links_panel, {size = 24})
    for _, v in ipairs(links) do
        link_button(v[1], v[2], links_panel)
    end

    -- guides panel
    text("Guides & Tutorials:", guides_panel, {size = 24})
    for _, v in ipairs(guides) do
        link_button(v[1], v[2], guides_panel)
    end

    credits_panel:AlignItems()
    links_panel:AlignItems()
    guides_panel:AlignItems()
    self:AlignItems()

end

function AboutMenu:Load(data)

end

function AboutMenu:Destroy()
    return {}
end