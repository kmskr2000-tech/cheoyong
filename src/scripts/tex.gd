class_name Tex
## Loads a sprite as a CanvasTexture with its generated normal map (<name>_n.png, art/normals.py),
## so 2D lights shade it with volume. Falls back to the plain texture when there is no normal map.

static var _cache := {}


static func lit(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var diffuse: Texture2D = load(path)
	var npath := path.get_basename() + "_n.png"
	var out: Texture2D = diffuse
	if ResourceLoader.exists(npath):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = diffuse
		ct.normal_texture = load(npath)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		out = ct
	_cache[path] = out
	return out
