--
-- Arcan "Workbench" theme
-- "inspired" by certain older desktop / windowing UIs
--

sysicons   = {};

-- the imagery pool is used as a data cache,
-- since the windowing subsystem need link_ calls to work
-- we can't use instancing, so instead we allocate a pool
-- and then share_storage
imagery    = {};
colortable = {};
minputtbl = {false, false, false};
groupicn    = "awbicons/drawer.png";
groupselicn = "awbicons/drawer_open.png";
deffont     = "fonts/topaz8.ttf";
deffont_sz  = 10;
linespace   = 4;

ORDER_MOUSE     = 255;

kbdbinds = {};

function menulbl(text, color)
	if (color == nil) then
		color = "\\#0055a9"
	end

	if (text) then
		text = string.gsub(text, "\\", "\\\\");
	end

	local vid, lineh = render_text(
		string.format("\\#0055a9\\f%s,%d %s", deffont, deffont_sz, text));
	return vid;
end

function desktoplbl(text, len)
	if (type(text) ~= "string") then
		print(debug.traceback());
	end

	if (len and len > 0) then
		text = string.sub(text, 1, string.utf8forward(text, len));
		print(text);
	end

	text = text == nil and "" or text;
	local vid, lineh = render_text(
		string.format("\\#ffffff\\f%s,%d %s",deffont, deffont_sz, text), linespace);
	return vid, lineh;
end

-- input is trusted, i.e. data supposedly comes from
-- the "add shortcut" etc. parts and has not been modified
-- by the user
function iconlbl(text)
	local ofs     = 0;
	local sz      = 10;
	local rowc    = 1;
	local newofs  = 1;
	local cc      = 0;
	local workstr = {};

	while newofs ~= ofs do
		ofs = newofs;
		cc = cc + 1;
		newofs = string.utf8forward(text, ofs);
		table.insert(workstr, string.sub(text, ofs, ofs));
		if (cc > 10) then
			rowc = rowc - 1;
			if (rowc < 0) then
				sz = 8;
				table.insert(workstr, "...");
				break;
			else
				table.insert(workstr, "\\n\\r");
				cc = 0;
			end
		end
	end

	return render_text(
		string.format("\\#ffffff\\f%s,%d %s", deffont,
			sz, table.concat(workstr, "")));
end

function inputlbl(text)
	text = text == nil and "" or text;
	return render_text(string.format("\\#ffffff\\f%s,%d %s",
		deffont, 12, text));
end

debug_global = {};

local function shortcut_str(caption, state)
	local res = {};

	table.insert(res, string.format(
		"local res = {};\nres.name=%q;\n" ..
		"res.caption=%q;\nres.icon=%q;\n" ..
		"res.factorystr = %q;\n", state.name, caption,
			state.icon and state.icon or "default",
			state.factorystr ~= nil and state.factorystr or state.factory));

	if (state.shortcut_trig) then
		table.insert(res, state.shortcut_trig());
	end

	table.insert(res, "return res;");
	return table.concat(res, "\n");
end

function shortcut_popup(icn, tbl, name)
	local popup_opts = [[Rename...\n\rDrop Shortcut]];
	local vid, list  = desktoplbl(popup_opts);

	local popup_fun = {
		function()
			local state = system_load("shortcuts/" .. name)();
			local buttontbl = {
				{ caption = desktoplbl("OK"), trigger =
				function(own)
					if (icn.set_caption == nil) then
						return;
					end
					zap_resource("shortcuts/" .. name);
						open_rawresource("shortcuts/" .. name);
						write_rawresource(shortcut_str(own.inputfield.msg, state));
					close_rawresource();
					icn:set_caption(desktoplbl(own.inputfield.msg));
				end
				},
				{ caption = desktoplbl("Cancel"), trigger = function(own) end }
				};

				local dlg = awbwman_dialog(desktoplbl("Rename To:"), buttontbl, {
					input = { w = 100, h = 20, limit = 32, accept = 1, cancel = 2 }
					}, false);
				end,
		function()
			zap_resource("shortcuts/" .. name);
			icn:destroy();
		end
	};

	awbwman_popup(vid, list, popup_fun);
end

function load_aux()
	system_load("awb_iconcache.lua")();

	system_load("awbwnd.lua")();
	system_load("awbwnd_icon.lua")();
	system_load("awbwnd_list.lua")();
	system_load("awbwnd_media.lua")();
	system_load("awbwnd_music.lua")();
	system_load("awbwnd_modelview.lua")();
	system_load("awbwnd_target.lua")();
	system_load("awbwnd_cli.lua")();

	system_load("awbwman.lua")();

	system_load("awb_browser.lua")();
	system_load("tools/inputconf.lua")();
	system_load("tools/vidrec.lua")();
 	system_load("tools/vidcmp.lua")();
 	system_load("tools/hghtmap.lua")();
	system_load("tools/socsrv.lua")();
	system_load("tools/vnc.lua")();
end

function awb(args)
	MESSAGE = system_load("language/default.lua")();
	arguments = args; -- emulate <= 0.4.0 globals

-- maintain a list of global symbols
-- from the launch, on a keypress, dump
-- anything that has been added / changed
-- to track down namespace pollution
	if (DEBUGLEVEL > 1) then
		for k,v in pairs(_G) do
			debug_global[k] = true;
		end
	end

	symtable = system_load("scripts/symtable.lua")();

	system_load("awb_support.lua")();
	system_load("scripts/3dsupport.lua")();
	setup_3dsupport(true);

--	system_load("scripts/resourcefinder.lua")();

-- mouse abstraction layer
-- (callbacks for click handlers, motion events etc.)
--
-- look in resources/scripts/mouse.lua
-- for heaps more options (gestures, trails, autohide)
--
	system_load("scripts/mouse.lua")();
	local cursor = load_image("awbicons/mouse.png", ORDER_MOUSE);
	image_tracetag(cursor, "mouse cursor");
	mouse_setup(cursor, ORDER_MOUSE, 1, true);

-- shutdown queued?
	if (parse_commandline() == false) then
		return;
	end

	load_aux(); -- support classes (awbwnd etc.)
	awbwman_init(desktoplbl, menulbl);

	awb_desktop_setup();

-- first time launching, show help window
	if (get_key("help_shown") == nil) then
		show_help();
	end

	map_inputs();

	local img = load_image("background.png");
	if (valid_vid(img)) then
		image_sharestorage( img, awbwman_cfg().root.canvas.vid );
		delete_image(img);
	end

--	awbwman_toggle_mousegrab();
	if (target_alloc) then
		setup_external_connections();
	end
end

function valid_adev(devnum)
	local tbl = inputanalog_query();
	local found = false;
	local resstr = {"Unknown device id specified, valid values:"};
	local devs = {};

	for k,v in ipairs(tbl) do
		if (not devs[v.devid]) then
			devs[v.devid] = true;
			table.insert(resstr, string.format("%d : %s", v.devid, v.label));
		end

		if (devnum == v.devid) then
			return true;
		end
	end

	shutdown(table.concat(resstr, "\n"));
	return false;
end

function parse_commandline()

	if arguments[1] == nil then
		return;
	end

	if (arguments[1] == "help" or arguments[1] == "--help" or
		arguments[1] == "-h") then
		shutdown([[
Arcan Workbench (AWB) command line options:
	amouse_dev=devind simulate mouse using analog device
	amouse_x=subid (if amouse_dev) axis to map to X
	amouse_y=subid (if amouse_dev) axis to map to Y
	amouse_btn=subid (if amouse_dev) button to map to LMB
	amouse_xf=fact (if amouse_dev) scaling factor to X
	amouse_yf=fact (if amouse_dev) scaling factor to Y
]]);
		return false;
	end

	local devtbl = {
		dev = 64,
		x = 0,
		y = 1,
		xf = 4.0,
		yf = 4.0,
		lmb = 0
	};

	for i=1, #arguments do
		local v = string.split(arguments[i], "=");
		local cmd = v[1] ~= nil and v[1] or "";
		local val = v[2] ~= nil and v[2] or "";
		local num = tonumber(val);

		if (cmd == "noauto") then
			noautores = true;

		elseif (cmd == "amouse_dev" and num ~= nil) then
			if (valid_adev(num) == false) then
				return false;
			end

			amouse_map = devtbl;
		elseif (cmd == "amouse_x" and num ~= nil) then
			devtbl.x = num;

		elseif (cmd == "amouse_y" and num ~= nil) then
			devtbl.y = num;

		elseif (cmd == "amouse_btn" and num ~= nil) then
			devtbl.lmb = num;

		elseif (cmd == "amouse_xf" and num ~= nil) then
			devtbl.xf = num;

		elseif (cmd == "amouse_yf" and num ~= nil) then
			devtbl.yf = num;

		else
			warning(string.format("unrecognized option: %s, ignored.", v[1]));
		end
	end

	return true;
end

function dumpvid()
	local px, ly = mouse_xy();
	local res = pick_items(px, ly, 1, 1);
	if (res[1] ~= nil) then
		local props = image_surface_properties(res[1]);
		local tag = image_tracetag(res[1]);
		print(string.format("(%d) tag: %s, pos: %f, %f, dimensions: %f, %f",
			res[1], tag ~= nil and tag or "no name", props.x,
			props.y, props.width, props.height));
	end
end

function map_inputs()
	if (DEBUGLEVEL > 1) then
		kbdbinds["F3"]     = function()
			zap_resource("syssnap.lua");
			system_snapshot("syssnap.lua");
		end

		kbdbinds["F5"]     = function() print(current_context_usage()); end;
		kbdbinds["F6"]     = debug.debug;
		kbdbinds["F10"]    = mouse_dumphandlers;
		kbdbinds["F8"]     = function()
			if (inrec ~= nil) then
				delete_image(inrec);
				inrec = nil;
			else
				print("recording on");
				inrec = alloc_surface(VRESW, VRESH, true);
				local nh = null_surface(VRESW, VRESH);
				show_image(nh);
				image_sharestorage(WORLDID, nh);
--				image_set_txcos_default(nh, true);
				zap_resource("recordings/dump.mkv");
				define_recordtarget(inrec, "recordings/dump.mkv",
					"vpreset=8:noaudio:fps=25", {nh}, {}, RENDERTARGET_DETACH,
					RENDERTARGET_NOSCALE, -2, function() end);
			end
		end

		kbdbinds["F4"]     = function()
			local newglob = {};

			print("[dump globals]");
			for k,v in pairs(_G) do
				if (debug_global[k] == nil) then
					print(k, v);
				end
				newglob[k] = true;
			end

			debug_global = newglob;
			print("[/dump globals]");
		end;
		kbdbinds["F7"] = dumpvid;
	end

	kbdbinds["LCTRL"]  = awbwman_toggle_mousegrab;
	kbdbinds["ESCAPE"] = awbwman_cancel;
	kbdbinds["F11"] = awbwman_gather_scatter;
	kbdbinds["F12"]	= awbwman_shadow_nonfocus;
end

--
-- Setup a frameserver session with an interactive target
-- as a new window, start with a "launching" canvas and
-- on activation, switch to the real one.
--
function gamelist_launch(self, factstr, coreargs)
	local game = self.tag;
	if (game == nil) then
		return;
	end

	targetwnd_setup(game, factstr, coreargs);
end

--
-- A target alloc loop that maps external connections
-- to target windows, re-using the same key.
--
-- This is slightly broken at the moment as we should
-- check what the window attempts to register itself as
-- and use that to map to the corresponding window class.
--
external_connections = {};

function external_connected(source, status)
	if (external_connections[source] == nil) then
		target_alloc("awb", external_connected);
		local wnd, cb = targetwnd_nonauth(source);
		wnd:add_handler("on_destroy", function()
			external_connections[source] = nil;
		end);
		external_connections[source] = {wnd, cb};
		wnd:rebuild_chain();
	end

	if (status.kind == "terminated") then
		if (external_connections[source]) then
			external_connections[source][2](source, status);
		end

		external_connections[source] = nil;

	elseif (status.kind == "registered") then
		external_connections[source][1].dir.t:update_caption(menulbl(status.title));
	end

--	external_connections[source](source, status);
end

function setup_external_connections()
	target_alloc("awb", external_connected);
end

function launch_factorytgt(tbl, factstr, coreopts)
	local lines  = string.split(factstr, "\n");
	local idline = lines[1];
	local idval  = tonumber(string.split(idline, "=")[2]);

	if (tbl.kind ~= nil and tbl.kind == "tool") then
		if (tbl.type == "vnc_client") then
			spawn_vncclient(tbl, factstr);
		end

		return;
	end

	warning("broken gameid / lnk, check database reference.");
end

function spawn_vidwin(self)
	local wnd = awbwman_capwnd(menulbl("Video Capture"),
		{refid = "vidcapwnd"});
end

function show_gamewarning()
	local wnd = awbwman_spawn(menulbl("Notice"), {noresize = true});
	if (wnd == nil) then
		return;
	end

	wnd:focus();

	local helpimg = desktoplbl(MESSAGE["WARNING_NOGAMES"]);
	link_image(helpimg, wnd.canvas.vid);
	show_image(helpimg);
	image_clip_on(helpimg, CLIP_SHALLOW);
	image_mask_set(helpimg, MASK_UNPICKABLE);
	image_inherit_order(helpimg, true);
	order_image(helpimg, 1);
	local props =	image_surface_properties(helpimg);
	move_image(helpimg, 10, 10);
	wnd:resize(props.width + 20, props.height + 20, true);

	wnd.lasthelp = helpimg;
end

function show_help()
	local wnd = awbwman_gethelper();
	local focusmsg = MESSAGE["HELP_GLOBAL"];
	local focus = awbwman_cfg().focus;

	if (focus ~= nil and type(focus.helpmsg) == "string" and
		string.len(focus.helpmsg) > 0) then
		focusmsg = focus.helpmsg;
	end

	if (wnd ~= nil) then
		wnd:focus();
		wnd.name = "Help Window";
		wnd:helpmsg(focusmsg);
		return;
	end

	local wnd = awbwman_spawn(menulbl("Help"), {noresize = true});
	if (wnd == nil) then
		return;
	end

	awbwman_sethelper( wnd );

	wnd.helpmsg = function(self, msg)
		if (wnd.lasthelp) then
			delete_image(wnd.lasthelp);
		end

		local helpimg = desktoplbl(msg);
		if (not valid_vid(helpimg)) then
			return;
		end
		link_image(helpimg, wnd.canvas.vid);
		show_image(helpimg);
		image_clip_on(helpimg, CLIP_SHALLOW);
		image_mask_set(helpimg, MASK_UNPICKABLE);
		image_inherit_order(helpimg, true);
		order_image(helpimg, 1);
		local props =	image_surface_properties(helpimg);
		move_image(helpimg, 10, 10);
		wnd:resize(props.width + 20, props.height + 20, true);

		wnd.lasthelp = helpimg;
	end

	wnd:helpmsg(focusmsg);

	local mh = {
		name = "help_handler",
		own = function(self, vid) return vid == wnd.canvas.vid; end,
		click = function() wnd:focus(); end
	};

	mouse_addlistener(mh, {"click"});
	table.insert(wnd.handlers, mh);

	wnd.on_destroy = function()
		store_key("help_shown", "yes");
		awbwman_sethelper ( nil );
	end
end

function sortopts_popup(ent, wnd)
	local sortfun = function() end
	local resort = function()
		table.sort(wnd.data, sortfun);
		wnd:force_update();
	end

	local popup_opts = [[Title(Asc)\n\rTitle(Desc)]];
	local popup_fun = {
		function() sortfun = function(a, b)
			return string.lower(a.title) < string.lower(b.title);
		end resort(); end,

		function() sortfun = function(a, b)
			return string.lower(a.title) > string.lower(b.title);
		end resort(); end,
	};

	local vid, lines = desktoplbl(popup_opts);
	awbwman_popup(vid, lines, popup_fun);
end

function gamelist_tblwnd(tbl, tgtname)
	if (tbl == nil or #tbl == 0) then
		return;
	end

	local pfg = string.lower(
		string.gsub(string.sub(tgtname, 1, 4), " ", ""));

	if (#tbl == 1) then
		local tag = {name = tgtname, target = tgtname};
		tag.tag = tag;
		tag.config = tbl[1];
		tag.prefix = pfg;
		gamelist_launch(tag);
		return;
	end

	local ltf = function(self) gamelist_launch(self); end;

	local wnd = awbwman_listwnd(menulbl(tgtname), deffont_sz, linespace,
		{0.7, 0.3}, function(filter, ofs, lim, iconw, iconh)
			local ul = ofs + lim;
			local res = {};

			ul = (ul > #tbl) and #tbl or ul;

			for i=ofs,ul do
				if (tbl[i] ~= nil) then
				local ent = {
					name = tbl[i],
					target = tgtname,
					config = tbl[i],
					trigger = ltf,
					prefix = pfg .. "_" .. string.gsub(
						string.sub(tbl[i], 1, 4), " ", ""),
					cols = {tbl[i]}
				};
				ent.tag = ent;
				table.insert(res, ent);
				end
			end

			return res, #tbl;
		end, desktoplbl, {});

	if (wnd ~= nil) then
		wnd.name = "List(" .. tgtname .. ")";
		wnd.data = tbl;
	end
end

last_bgwin = nil;
local function background_tagh(funptr, wnd, srcvid)

-- set as new background
	image_sharestorage(srcvid, awbwman_cfg().root.canvas.vid);
	background_dirty = true; -- save upon closing
end

local function register_bghandler(wnd)
	if (last_bgwin == wnd) then
		return;
	end

-- de-register from last window that updated
	if (last_bgwin ~= nil) then
		last_bgwin:drop_handler("on_update", background_tagh);
	end

-- add to updatehandler for new window
	wnd:add_handler("on_update", background_tagh);
end

function gamelist_wnd(selection)
	local tgtname = selection.name;
	local tgttotal = target_configurations(tgtname);
	gamelist_tblwnd(tgttotal, tgtname);
end

function add_shortcut(dst, ctag)
	local ind  = 1;
--	local base = string.match(ctag.caption, "[%a %d_-]+");
	local line = "shortcuts/" .. dst .. ".lua";

	if (open_rawresource(line)) then
		write_rawresource(shortcut_str(dst, ctag));
		close_rawresource();
	else
		return false;
	end

	if (not awbwman_rootgeticon(dst)) then
		local res = system_load(line, 0);
		if (res == nil) then
			return;
		end

		local tbl = res();

		if (tbl ~= nil and
			tbl.factorystr and
			tbl.name and tbl.caption) then

			local icn, w, h = get_root_icon(tbl.icon);
			local icn = awbwman_rootaddicon(tbl.name, iconlbl(tbl.caption),
				icn, icn,
				function()
					launch_factorytgt(tbl, tbl.factorystr);
				end,
				function(self)
					shortcut_popup(self, tbl, dst .. ".lua");
				end,
				{w = w, h = h, helper = tbl.caption}
			);

			local mx, my = mouse_xy();
			icn.x = mx;
			icn.y = my;
			move_image(icn.anchor, icn.x, icn.y);
		end
	end
end

function rootdnd(ctag)
	local lbls = {};
	local ftbl = {};

--
-- If we can use a string- reference as allocation function
-- (this needs to be stored on the database, read on desktup setup
-- and use the construction string to rebuild on activation)
--
	if (ctag.conststr) then
		table.insert(lbls, "Shortcut");
		table.insert(ftbl, function() end);
	end

	if (ctag.source and ctag.source.canvas
		and valid_vid(ctag.source.canvas.vid)) then
		table.insert(lbls, "Background");
		table.insert(ftbl,
			function()
				image_sharestorage(ctag.source.canvas.vid,
					awbwman_cfg().root.canvas.vid);
				background_dirty = true; -- save upon closing
				register_bghandler(ctag.source);
			end);
	end

	if (ctag.factory) then
		table.insert(lbls, "Add Shortcut");
		table.insert(ftbl, function()
			local buttontbl = {
				{
					caption = desktoplbl("OK"),
					trigger =
						function(own)
							add_shortcut(own.inputfield.msg, ctag);
						end
				},
				{
					caption = desktoplbl("Ccancel"),
					trigger = function() end
				}
			};
			local dlg = awbwman_dialog(desktoplbl("Shortcut Name:"), buttontbl,
			{input = {w = 100, h = 20, limit = 32, accept = 1, cancel = 2}},
			false);
		end);
	end

	if (#lbls > 0) then
		local vid, lines = desktoplbl(table.concat(lbls, "\\n\\r"));
		awbwman_popup(vid, lines, ftbl);
	end
end

local function amediahandler(path, base, ext)
	local name = path .. "/" .. base .. "." .. ext;
	local awbwnd = awbwnd_globalmedia();

	if (awbwnd == nil) then
		awbwnd = awbwman_aplayer(menulbl("Music Player"));
	end

	awbwnd:add_playitem(base, name);

-- animate where the playlist item is actually going
	local aspeed = awbwman_cfg().animspeed;
	local lbl = desktoplbl(string.gsub(
		string.sub(base, 1, 8), "\\", "\\\\"));
	show_image(lbl);
	local x, y = mouse_xy();
	move_image(lbl, x, y);

	if (awbwnd.minimized == true) then
		blend_image(lbl, 1.0, aspeed * 2);
		move_image(lbl, 40, 0, aspeed);
		move_image(lbl, 40, 0, aspeed);
		blend_image(lbl, 0.0, aspeed);
	else
		local prop = image_surface_properties(lbl);
		local dstx = -1 * 0.5 * prop.width;
		local dstw = awbwnd.playlistwnd ~= nil and awbwnd.playlistwnd or awbwnd;

		prop = image_surface_properties(dstw.canvas.vid);
		dstx = dstx + prop.width * 0.5;

		link_image(lbl, dstw.canvas.vid);
		image_inherit_order(lbl, true);
		move_image(lbl, prop.x - x, prop.y - y);
		blend_image(lbl, 1.0, aspeed * 2);
		move_image(lbl, dstx, prop.height * 0.5, aspeed);
		move_image(lbl, dstx, prop.height * 0.5, aspeed);
		blend_image(lbl, 0.0, aspeed);
	end

	expire_image(lbl, aspeed * 3);
end

local function vmediahandler(path, base, ext)
	local name = path .. "/" .. base .. "." .. ext;
	local wnd, tfun = awbwman_mediawnd(menulbl("Media Player"));
	local vid, aid = launch_decode(name, "loop", tfun);
	wnd.controlid = vid;
	wnd.recv = aid;
	wnd.name = base;
end

local function imghandler(path, base, ext)
	local wnd, tfun = awbwman_imagewnd(menulbl(base), nil);
	local name = path .. "/" .. base .. "." .. ext;
	load_image_asynch(name, tfun);
end

local exthandler = {
	MP3 = amediahandler,
	OGG = amediahandler,
	FLAC = amediahandler,
	M4A = amediahandler,
	FLV = vmediahandler,
	MKV = vmediahandler,
	MOV = vmediahandler,
	MP4 = vmediahandler,
	AVI = vmediahandler,
	MPG = vmediahandler,
	MPEG= vmediahandler,
	JPG = imghandler,
	PNG = imghandler
};

local function wnd_3dmodels()
	local list = {};
	local res = glob_resource("models/*");

	local mtrig =
	function(a, b)
		local model = setup_cabinet_model(
			a.name, {}, {});
		if (model and model.vid) then
			move3d_model(model.vid, 0.0, -0.2, -2.0);
			awbwman_modelwnd(menulbl(a.name), model);
		end
	end

	for k,l in ipairs(res) do
		local ent = {};
		ent.trigger = mtrig;
		ent.name = tostring(l);
		ent.cols = {tostring(l)};

		table.insert(list, ent);
	end

	if (#list == 0) then
		return;
	end

	local wnd = awbwman_listwnd(menulbl("3D Models"), deffont_sz,
		linespace, {1.0}, list, desktoplbl);

	wnd.name = "3D Models";
end

local function wnd_media(path)
	local list = {};
	local res = glob_resource(path .. "/*");

	for k,l in ipairs(res) do
		table.insert(list, l);
	end

	if (#list == 0) then
		return;
	end

	table.sort(list, function(a, b)
		local ab, ax = string.extension(a);
		local bb, bx = string.extension(b);
	end);

	local wnd = awbwman_listwnd(menulbl("MediaBrowser"),
		deffont_sz, linespace, {1.0},
		function(filter, ofs, lim)
			local res = {};
			local ul = ofs + lim - 1;

			for i=ofs, ul do
				local ment = {
					resource = list[i],
					trigger  = function()
						local base, ext = string.extension(list[i]);
						local handler = exthandler[
							string.upper(ext ~= nil and ext or "") ];

						if (handler) then
							handler(path, base, ext);
						else
							wnd_media(path .. "/" .. list[i]);
						end
					end,
					name = "mediaent",
					cols = {list[i]}
				};
-- FIXME: prefix icon based on extension, use that to set icon
				table.insert(res, ment);
			end
			return res, #list;
		end, desktoplbl);
	wnd.name = "Media Browser";
end

function awb_desktop_setup()
	sysicons.group        = load_image("awbicons/drawer.png");
	sysicons.group_active = load_image("awbicons/drawer_open.png");
	sysicons.boing        = load_image("awbicons/boing.png");
	sysicons.floppy       = load_image("awbicons/floppy.png");
	sysicons.shell        = load_image("awbicons/shell.png");

	sysicons.lru_cache    = awb_iconcache(64,
		{"images/icons", "icons", "images/systems", "awbicons"}, sysicons.floppy);

	local groups = {
		{
			name    = MESSAGE["GROUP_TOOLS"],
			key     = "tools",
			trigger = function()
			local wnd = awbwman_iconwnd(menulbl(MESSAGE["GROUP_TOOLS"]),
				builtin_group, {refid = "iconwnd_tools"});
				wnd.name = "List(Tools)";
			end
		},
		{
			name    = MESSAGE["GROUP_SYSTEMS"],
			key     = "systems",
			trigger = function()
				local tbl =	awbwman_iconwnd(menulbl(MESSAGE["GROUP_SYSTEMS"]),
					system_group, {refid = "iconwnd_systems"});
				tbl.idfun = list_targets;
				tbl.name = "List(Systems)";
			end
		},
		{
			name = MESSAGE["GROUP_MODELS"],
			key = "models",
			trigger = wnd_3dmodels
		},
		{
			name = MESSAGE["GROUP_MUSIC"],
			key  = "music",
			trigger = function()
				wnd_media("music");
			end
		},
		{
			name = MESSAGE["GROUP_RECORDINGS"],
			key = "recordings",
			trigger = function()
				wnd_media("recordings");
			end
		},
		{
			name = MESSAGE["GROUP_VIDEOS"],
			key = "videos",
			trigger = function()
				wnd_media("videos");
			end
		},
	};

	for i,j in pairs(groups) do
		local lbl = desktoplbl(j.name);
		awbwman_rootaddicon(j.key, lbl, sysicons.group,
			sysicons.group_active, j.trigger, j.rtrigger);
	end

	local cfg = awbwman_cfg();
	cfg.on_rootdnd = rootdnd;

	local rtbl = glob_resource("shortcuts/*.lua");
	if (rtbl) then
		for k,v in ipairs(rtbl) do
			local tbl = system_load("shortcuts/" .. v)();
			if (tbl ~= nil and
				tbl.factorystr and tbl.name and tbl.caption) then
				local icn, desw, desh = get_root_icon(tbl.icon);

				awbwman_rootaddicon(tbl.name, iconlbl(tbl.caption),
				icn, icn, function()
					launch_factorytgt(tbl, tbl.factorystr, tbl.coreopts); end,
					function(self) shortcut_popup(self, tbl, v); end,
				{w = desw, h = desh, helper = tbl.caption});
			end
		end
	end
end

function get_root_icon(hint)
	local icn = sysicons.lru_cache:get(hint).icon;
	local props = image_surface_properties(icn);
	local desw = 48; local desh = 48;
	if (props.width < 48 and props.height < 48) then
		desw = nil;
		desh = nil;
	end
	return icn, desw, desh;
end

local function vnc_interim()
	spawn_vncclient();
end

function builtin_group(self, ofs, lim, desw, desh)
	local tools = {
 		{"BOING!",    spawn_boing, "boing"   },
		{"CLI",       spawn_shell, "shell"   },
		{"Input",     awb_inputed, "inputed" },
		{"Recorder",  function() spawn_vidrec(false); end, "vidrec" },
		{"Remoting",  function() spawn_vidrec(true); end, "remoting" },
		{"Compare",   spawn_vidcmp, "vidcmp" },
--		{"Network",   spawn_socsrv, "network"},
		{"VNC", function() spawn_vncclient(); end, "remoting_cl" },
		{"VidCap",    spawn_vidwin, "vidcap" },
		{"HeightMap", spawn_hmap, "hghtmap"  }
	};

 	local restbl = {};

	lim = lim + ofs;
	while ofs <= lim and ofs <= #tools do
 		local newtbl = {};
   	newtbl.caption = desktoplbl(tools[ofs][1]);
   	newtbl.trigger = tools[ofs][2];
   	newtbl.name = tools[ofs][3];
   	newtbl.icon = sysicons.lru_cache:get(newtbl.name).icon;
   	table.insert(restbl, newtbl);
   	ofs = ofs + 1;
  end

	return restbl, #tools;
end

function system_group(self, ofs, lim, desw, desh)
	if (system_group_last == nil or CLOCK - system_group_last > 1000) then
		system_group_last = CLOCK;
		system_group_targets = list_targets();
		for i=#system_group_targets,1,-1 do
			local cfg = target_configurations(system_group_targets[i]);
			if (not cfg or #cfg == 0) then
				table.remove(system_group_targets, i);
			end
		end
	end

	local restbl = {};

	lim = lim + ofs;
	while ofs <= lim and ofs <= #system_group_targets do
		local newtbl = {};
		newtbl.caption = desktoplbl(system_group_targets[ofs]);
		newtbl.trigger = gamelist_wnd;
		newtbl.name    = system_group_targets[ofs];
		newtbl.icon    = sysicons.lru_cache:get(newtbl.name).icon;
		table.insert(restbl, newtbl);
		ofs = ofs + 1;
	end

	return restbl, #system_group_targets;
end

function spawn_shell()
	local wnd, tfun = awbwman_cliwnd(menulbl("CLI"));
	local argstr = "env=ARCAN_CONNPATH=awb:";

	local col = awbwman_cfg().col;

--	for i=1,15 do
--		argstr = argstr .. string.format("ci=%d,255,255,255:", i);
--	end

	argstr = argstr .. string.format("bgc=%d,%d,%d:fgc=255,255,255:cc=240,128,0",
		col.bgcolor.r, col.bgcolor.g, col.bgcolor.b);

	wnd.controlid = launch_avfeed(argstr, "terminal", tfun);
	image_sharestorage(wnd.controlid, wnd.canvas.vid);
	wnd.name = "cli";
	if (not valid_vid(wnd.controlid)) then
		wnd:destroy();
		return;
	end
end

--
-- A little hommage to the original, shader is from rendertoy
--
function spawn_boing(caption)
	local int oval = math.random(1,100);
	local a = awbwman_spawn(menulbl("Boing!"));
	if (a == nil) then
		return;
	end

	a.name = "Boing!";
	a.kind = sysicons.boing;

	local boing = load_shader(nil, "shaders/boing.fShader",
		"boing" .. oval, {});

	local props = image_surface_properties(a.canvas.vid);
		a.canvas.resize = function(self, neww, newh)
		shader_uniform(boing, "display", "ff", PERSIST, neww, newh);
		shader_uniform(boing, "offset", "i", PERSIST, oval);
		resize_image(self.vid, neww, newh);
	end

	image_shader(a.canvas.vid, boing);
	a.canvas:resize(props.width, props.height);

	return a;
end

-- to control the cursor through another device
function translate_adev(iotbl)
	local cfg = awbwman_cfg();
	if (iotbl.kind == "analog" and not cfg.mouse_focus) then
		if (iotbl.subid == amouse_map.x) then
			iotbl.source = "mouse";
			mouse_state().tick_state = minputtbl; -- set this earlier
			mouse_state().tick_dx = iotbl.samples[1] / 32768.0 * amouse_map.xf;

		elseif (iotbl.subid == amouse_map.y) then
			mouse_state().tick_dy = iotbl.samples[1] / 32768.0 * amouse_map.yf;
			iotbl.source = "mouse";
		end

	elseif (iotbl.kind == "digital") then
		if (iotbl.subid == amouse_map.lmb) then
			minputtbl[1] = iotbl.active;
			mouse_input(0, 0, minputtbl);
		end
	end

	return iotbl;
end

function awb_display_state(state, data)
	awbwman_displaystate(state, data);
end

local mid_c = 0;
local mid_v = {0, 0};
function awb_input(iotbl)
-- if not locked to a window, and enabled,
-- map an analog device to emitt the same events as the mouse would

	if (amouse_map and iotbl.devid == amouse_map.dev) then
		iotbl = translate_adev(iotbl);
	end

	if (iotbl.kind == "analog" and iotbl.source == "mouse") then
		if (iotbl.relative) then
			if (iotbl.subid == 0) then
				mouse_input(iotbl.samples[2], 0);
			else
				mouse_input(0, iotbl.samples[2]);
			end
		else
			mid_v[iotbl.subid+1] = iotbl.samples[1];
			mid_c = mid_c + 1;
			if (mid_c == 2) then
				mouse_absinput(mid_v[1], mid_v[2]);
				mid_c = 0;
			end
		end

	elseif (iotbl.kind == "digital" and iotbl.source == "mouse") then
		if (iotbl.subid > 0 and iotbl.subid <= 3) then

-- meta converts LMB to RMB
--			if (iotbl.subid == 1 and awbwman_cfg().meta.shift) then
--				iotbl.subid = 3;
--			end

			minputtbl[iotbl.subid] = iotbl.active;
			if (awbwman_minput(iotbl)) then
				mouse_button_input(iotbl.subid, iotbl.active);
			end
		end

	elseif (iotbl.kind == "digital") then
		iotbl.lutsym = symtable[iotbl.keysym];
		if (iotbl.lutsym == nil) then
			iotbl.lutsym = "UNKNOWN";
		end

		local kbdbindbase = awbwman_meta() .. iotbl.lutsym;
		local forward = true;

		if (iotbl.lutsym == "LSHIFT" or iotbl.lutsym == "RSHIFT") then
			awbwman_meta("shift", iotbl.active);
		end

		if (iotbl.lutsym == "LALT" or iotbl.lutsym == "RALT") then
			awbwman_meta("alt", iotbl.active);
		end

		if (iotbl.active and kbdbinds[ kbdbindbase ]) then
			forward = kbdbinds[ kbdbindbase ]() == nil;
		end

		if (forward) then
			awbwman_input(iotbl, kbdbindbase);
		end

	elseif (iotbl.kind == "analog") then
			awbwman_ainput(iotbl);
	end
end

function awb_shutdown()
	if (background_dirty) then
		zap_resource("background.png");
		save_screenshot("background.png", 0,
			awbwman_cfg().root.canvas.vid);
	end
end

local OLDW = VRESW;
local OLDH = VRESH;
function VRES_AUTORES(w, h, vppcm, flags, source)
	if (noautores) then
		return;
	end

	resize_video_canvas(w, h);
	awbwman_relayout(w - OLDW, h - OLDH);
	OLDW = w;
	OLDH = h;
end
