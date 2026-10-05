Hooks:Add("BeardLibAddElement", "BLEInjectElements", function(module, directory, element)
    table.insert(BLE._config.MissionElements, element.name .. "Element")
    local editor_file = element.file:gsub("Element", "ElementEditor")
    local possible_editor = Path:Combine(directory, editor_file)
    if FileIO:Exists(possible_editor) then
        dofile(possible_editor)
    end
end)