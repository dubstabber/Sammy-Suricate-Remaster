extends RefCounted
class_name WmbManifest

var data: Dictionary = {}
var source_path: String = ""


func load_file(path: String) -> Error:
    source_path = path
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()

    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return ERR_PARSE_ERROR

    data = parsed
    return OK


func get_counts() -> Dictionary:
    return data.get("counts", {})


func has_level(level_name: String) -> bool:
    return not find_level(level_name).is_empty()


func find_level(level_name: String) -> Dictionary:
    var wanted := level_name.to_lower()
    for item: Dictionary in data.get("external_wmb_copies", []):
        var output_name := String(item.get("output", "")).get_file().to_lower()
        var source_name := String(item.get("source", "")).get_file().to_lower()
        if output_name == wanted or source_name == wanted:
            return item
    return {}


func external_level_names() -> Array[String]:
    var names: Array[String] = []
    for item: Dictionary in data.get("external_wmb_copies", []):
        names.append(String(item.get("output", "")).get_file())
    return names
