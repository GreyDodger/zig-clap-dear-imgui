const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("clap/clap.h");
    @cInclude("string.h");
    @cInclude("stdarg.h");
    if (builtin.os.tag == .windows) {
        @cInclude("win32_console_log.c");
    }
    @cInclude("cimgui.h");
});

const std = @import("std");
const ArrayList = std.ArrayList;
const util = @import("util.zig");
const c_cast = std.zig.c_translation.cast;
const global = @import("global.zig");

extern fn myDLLMain(hinstance: std.os.windows.HINSTANCE, fdwReason: std.os.windows.DWORD) callconv(.C) void;
pub fn DllMain(hinstance: std.os.windows.HINSTANCE, fdwReason: std.os.windows.DWORD, lpvReserved: std.os.windows.LPVOID) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
    _ = lpvReserved;
    myDLLMain(hinstance, fdwReason);
    return std.os.windows.TRUE;
}

const Gui = struct {
    extern fn platformGuiCreate(ptr: *const ?*anyopaque, plugin: [*c]const c.clap_plugin_t, init_width: u32, init_height: u32) callconv(.C) void;
    extern fn platformGuiDestroy(ptr: ?*anyopaque) callconv(.C) void;
    extern fn platformGuiSetParent(ptr: ?*anyopaque, window: [*c]const c.clap_window_t) callconv(.C) void;
    extern fn platformGuiSetSize(ptr: ?*anyopaque, width: [*c]u32, height: [*c]u32) callconv(.C) void;
    extern fn platformGuiGetSize(ptr: ?*anyopaque, width: [*c]u32, height: [*c]u32) callconv(.C) void;
    extern fn platformGuiShow(ptr: ?*anyopaque) callconv(.C) void;
    extern fn platformGuiHide(ptr: ?*anyopaque) callconv(.C) void;
    extern fn dllMain() callconv(.C) void;

    client_width: u32 = 0,
    client_height: u32 = 0,

    pub export fn imGuiFrame(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);

        c.ImGui_NewFrame();
        defer c.ImGui_Render();

        {
            _ = c.ImGui_Begin("Misc", null, 0);
            defer c.ImGui_End();

            {
                var str = std.fmt.allocPrintZ(global.allocator, "Sample Rate: {d:.2}", .{plug.sample_rate}) catch unreachable;
                defer global.allocator.free(str);
                c.ImGui_TextUnformatted(str.ptr);
            }

            _ = c.ImGui_Checkbox("Bypass Filter", &MyPlugin.bypass_filter);
        }

        {
            _ = c.ImGui_Begin("Params", null, 0);
            defer c.ImGui_End();

            const fields = std.meta.fields(Params.Values);
            inline for (fields) |field, field_index| {
                const meta = Params.value_metas[field_index];

                c.ImGui_PushID(meta.name.ptr);
                defer c.ImGui_PopID();

                switch (meta.t) {
                    .Bool => {
                        var value = @field(plug.params.values, field.name) > 0.5;
                        if (c.ImGui_Checkbox(meta.name.ptr, &value)) {
                            @field(plug.params.values, field.name) = if (value) 1.0 else 0.0;
                        }
                    },
                    .FilterCoefficient => {
                        if (c.ImGui_Button("-1")) {
                            @field(plug.params.values, field.name) = -1;
                        }
                        c.ImGui_SameLine();
                        if (c.ImGui_Button("0")) {
                            @field(plug.params.values, field.name) = 0;
                        }
                        c.ImGui_SameLine();
                        if (c.ImGui_Button("1")) {
                            @field(plug.params.values, field.name) = 1;
                        }
                        c.ImGui_SameLine();
                        var value = @floatCast(f32, @field(plug.params.values, field.name));
                        if (c.ImGui_DragFloatEx(meta.name.ptr, &value, 0.001, meta.min_value, meta.max_value, "%.3f", 0)) {
                            @field(plug.params.values, field.name) = @floatCast(f64, value);
                        }
                    },
                    else => {
                        var value = @floatCast(f32, @field(plug.params.values, field.name));
                        if (c.ImGui_DragFloatEx(meta.name.ptr, &value, 0.001, meta.min_value, meta.max_value, "%.3f", 0)) {
                            @field(plug.params.values, field.name) = @floatCast(f64, value);
                        }
                    },
                }
            }
        }

        c.ImGui_ShowDemoWindow(null);
    }

    // Returns true if the requested gui api is supported
    // [main-thread]
    fn is_api_supported(plugin: [*c]const c.clap_plugin_t, api: [*c]const u8, is_floating: bool) callconv(.C) bool {
        _ = plugin;
        if (c.strcmp(api, &c.CLAP_WINDOW_API_WIN32) == 0 and !is_floating) {
            return true;
        } else if (c.strcmp(api, &c.CLAP_WINDOW_API_COCOA) == 0 and !is_floating) {
            return true;
        }
        return false;
    }

    // Returns true if the plugin has a preferred api.
    // The host has no obligation to honor the plugin preferrence, this is just a hint.
    // The const char **api variable should be explicitly assigned as a pointer to
    // one of the CLAP_WINDOW_API_ constants defined above, not strcopied.
    // [main-thread]
    fn get_preferred_api(plugin: [*c]const c.clap_plugin_t, api: [*c][*c]const u8, is_floating: [*c]bool) callconv(.C) bool {
        _ = plugin;
        _ = api;
        _ = is_floating;
        return true;
    }

    // Set the absolute GUI scaling factor, and override any OS info.
    // Should not be used if the windowing api relies upon logical pixels.
    //
    // If the plugin prefers to work out the scaling factor itself by querying the OS directly,
    // then ignore the call.
    //
    // Returns true if the scaling could be applied
    // Returns false if the call was ignored, or the scaling could not be applied.
    // [main-thread]
    fn set_scale(plugin: [*c]const c.clap_plugin_t, scale: f64) callconv(.C) bool {
        _ = plugin;
        _ = scale;
        return true;
    }

    // Returns true if the window is resizeable (mouse drag).
    // Only for embedded windows.
    // [main-thread]
    fn can_resize(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        _ = plugin;
        return true;
    }

    // Returns true if the plugin can provide hints on how to resize the window.
    // [main-thread]
    fn get_resize_hints(plugin: [*c]const c.clap_plugin_t, hints: [*c]c.clap_gui_resize_hints_t) callconv(.C) bool {
        _ = plugin;
        _ = hints;
        return true;
    }

    // If the plugin gui is resizable, then the plugin will calculate the closest
    // usable size which fits in the given size.
    // This method does not change the size.
    //
    // Only for embedded windows.
    // [main-thread]
    fn adjust_size(plugin: [*c]const c.clap_plugin_t, width: [*c]u32, height: [*c]u32) callconv(.C) bool {
        _ = plugin;
        _ = width;
        _ = height;
        return true;
    }

    // Set the plugin floating window to stay above the given window.
    // [main-thread & floating]
    fn set_transient(plugin: [*c]const c.clap_plugin_t, window: [*c]const c.clap_window_t) callconv(.C) bool {
        _ = plugin;
        _ = window;
        return true;
    }

    // Suggests a window title. Only for floating windows.
    // [main-thread & floating]
    fn suggest_title(plugin: [*c]const c.clap_plugin_t, title: [*c]const u8) callconv(.C) void {
        _ = plugin;
        _ = title;
    }

    // Show the window.
    // [main-thread]
    fn show(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        platformGuiShow(plug.platform_gui_data);
        return true;
    }

    // Hide the window, this method does not free the resources, it just hides
    // the window content. Yet it may be a good idea to stop painting timers.
    // [main-thread]
    fn hide(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        platformGuiHide(plug.platform_gui_data);
        return true;
    }

    fn guiCreate(plugin: [*c]const c.clap_plugin_t, api: [*c]const u8, is_floating: bool) callconv(.C) bool {
        _ = api;
        _ = is_floating;
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        platformGuiCreate(&plug.platform_gui_data, plugin, plug.gui.client_width, plug.gui.client_height);
        return true;
    }
    fn guiDestroy(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        platformGuiDestroy(plug.platform_gui_data);
    }
    fn guiSetParent(plugin: [*c]const c.clap_plugin_t, window: [*c]const c.clap_window_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        platformGuiSetParent(plug.platform_gui_data, window);
        return true;
    }
    fn guiSetSize(plugin: [*c]const c.clap_plugin_t, width: u32, height: u32) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        plug.gui.client_width = width;
        plug.gui.client_height = height;
        platformGuiSetSize(plug.platform_gui_data, width, height);
        return true;
    }
    fn guiGetSize(plugin: [*c]const c.clap_plugin_t, width: [*c]u32, height: [*c]u32) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        platformGuiGetSize(plug.platform_gui_data, width, height);
        plug.gui.client_width = width.*;
        plug.gui.client_height = height.*;
        return true;
    }

    fn serializedSize(_: Gui) usize {
        return @sizeOf(u32) * 2;
    }
    fn serialize(self: Gui, stream: *const c.clap_ostream_t) !void {
        try State.write(stream, self.client_width);
        try State.write(stream, self.client_height);
    }
    fn deserialize(self: *Gui, stream: *const c.clap_istream_t) !usize {
        self.client_width = try State.read(stream, u32);
        self.client_height = try State.read(stream, u32);
        return self.serializedSize();
    }

    const Data = c.clap_plugin_gui_t{
        .is_api_supported = is_api_supported,
        .get_preferred_api = get_preferred_api,

        // Create and allocate all resources necessary for the gui.
        //
        // If is_floating is true, then the window will not be managed by the host. The plugin
        // can set its window to stays above the parent window, see set_transient().
        // api may be null or blank for floating window.
        //
        // If is_floating is false, then the plugin has to embbed its window into the parent window, see
        // set_parent().
        //
        // After this call, the GUI may not be visible yet; don't forget to call show().
        // [main-thread]
        .create = guiCreate,

        // Free all resources associated with the gui.
        // [main-thread]
        .destroy = guiDestroy,
        .set_scale = set_scale,

        // Get the current size of the plugin UI.
        // clap_plugin_gui->create() must have been called prior to asking the size.
        // [main-thread]
        .get_size = guiGetSize,
        .can_resize = can_resize,
        .get_resize_hints = get_resize_hints,
        .adjust_size = adjust_size,
        // Sets the window size. Only for embedded windows.
        // [main-thread]
        .set_size = guiSetSize,

        // Embbeds the plugin window into the given window.
        // [main-thread & !floating]
        .set_parent = guiSetParent,
        .set_transient = set_transient,
        .suggest_title = suggest_title,
        .show = show,
        .hide = hide,
    };
};

pub const Params = struct {
    values: Values = Values{},

    const ValueMeta = struct {
        id: u32,
        name: []const u8 = &[_]u8{},
        t: ValueType = .VolumeAmp,
        min_value: f64 = 0.0,
        max_value: f64 = 1.0,
    };

    const ValueType = enum {
        Bool,
        VolumeAmp,
        VolumeDB,
        TimeSamples,
        TimeMilliseconds,
        TVal, // 0 to 1
        FilterCoefficient,
    };

    const Values = struct {
        stereo: f64 = 1.0,
        gain_amplitude_main: f64 = 0.5,

        a0: f64 = 1.0,
        a1: f64 = 0.0,
        a2: f64 = 0.0,

        b1: f64 = 0.0,
        b2: f64 = 0.0,
    };

    const value_metas = [std.meta.fields(Values).len]ValueMeta{
        .{ .id = 0x5da004c1, .name = "Stereo", .t = .Bool },
        .{ .id = 0xe100e598, .name = "Volume" },
        .{ .id = 0xe100e599, .name = "A0", .t = .FilterCoefficient, .min_value = -2, .max_value = 2 },
        .{ .id = 0xe100e59A, .name = "A1", .t = .FilterCoefficient, .min_value = -2, .max_value = 2 },
        .{ .id = 0xe100e59B, .name = "A2", .t = .FilterCoefficient, .min_value = -2, .max_value = 2 },
        .{ .id = 0xe100e59C, .name = "B1", .t = .FilterCoefficient, .min_value = -2, .max_value = 2 },
        .{ .id = 0xe100e59D, .name = "B2", .t = .FilterCoefficient, .min_value = -2, .max_value = 2 },
    };

    comptime {
        var i: usize = 0;
        while (i < value_metas.len) : (i += 1) {
            var j = i + 1;
            while (j < value_metas.len) : (j += 1) {
                if (value_metas[i].id == value_metas[j].id) {
                    @compileLog("Repeating IDs ", i, j);
                }
            }
        }
    }

    fn idToValueIndex(id: u32) !usize {
        const fields = std.meta.fields(Values);
        inline for (fields) |_, field_index| {
            if (value_metas[field_index].id == id) {
                return field_index;
            }
        }
        return error.CantFindValue;
    }
    fn idToValue(self: Params, id: u32) !f64 {
        const fields = std.meta.fields(Values);
        inline for (fields) |field, field_index| {
            if (value_metas[field_index].id == id) {
                return @field(self.values, field.name);
            }
        }
        return error.CantFindValue;
    }
    fn idToValuePtr(self: *Params, id: u32) !*f64 {
        const fields = std.meta.fields(Values);
        inline for (fields) |field, field_index| {
            if (value_metas[field_index].id == id) {
                return &@field(self.values, field.name);
            }
        }
        return error.CantFindValue;
    }

    fn count(plugin: [*c]const c.clap_plugin_t) callconv(.C) u32 {
        _ = plugin;
        return std.meta.fields(Values).len;
    }

    fn get_info(plugin: [*c]const c.clap_plugin_t, index: u32, info: [*c]c.clap_param_info_t) callconv(.C) bool {
        _ = plugin;
        const fields = std.meta.fields(Values);
        switch (index) {
            inline 0...(fields.len - 1) => |comptime_index| {
                const field = fields[comptime_index];
                var flags: u32 = if (value_metas[index].t == .Bool) c.CLAP_PARAM_IS_STEPPED else 0;
                flags |= c.CLAP_PARAM_IS_AUTOMATABLE;
                info.* = .{
                    .id = value_metas[index].id,
                    .name = undefined,
                    .module = undefined,
                    .min_value = value_metas[index].min_value,
                    .max_value = value_metas[index].max_value,
                    .default_value = @ptrCast(*const f64, @alignCast(@alignOf(field.field_type), field.default_value.?)).*,
                    .flags = flags,
                    .cookie = null,
                };
                if (value_metas[index].name.len > 0) {
                    _ = std.fmt.bufPrintZ(&info.*.name, "{s}", .{value_metas[index].name}) catch unreachable;
                } else {
                    _ = std.fmt.bufPrintZ(&info.*.name, field.name, .{}) catch unreachable;
                }
                _ = std.fmt.bufPrintZ(&info.*.module, "params/" ++ field.name, .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }
    fn get_value(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, out: [*c]f64) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        out.* = plug.params.idToValue(id) catch {
            return false;
        };
        return true;
    }
    fn value_to_text(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, value: f64, buf_ptr: [*c]u8, buf_size: u32) callconv(.C) bool {
        _ = plugin;
        var buf: []u8 = buf_ptr[0..buf_size];
        var index = idToValueIndex(id) catch {
            return false;
        };
        switch (value_metas[index].t) {
            .Bool => {
                _ = std.fmt.bufPrintZ(buf, "{s}", .{if (value == 0.0) "false" else "true"}) catch unreachable;
            },
            .VolumeAmp => {
                const display = util.amplitudeTodB(@floatCast(f32, value));
                _ = std.fmt.bufPrintZ(buf, "{d:.4} dB", .{display}) catch unreachable;
            },
            .TimeMilliseconds => {
                _ = std.fmt.bufPrintZ(buf, "{d:.4} ms", .{value}) catch unreachable;
            },
            else => {
                _ = std.fmt.bufPrintZ(buf, "{d:.4}", .{value}) catch unreachable;
            },
        }
        return true;
    }
    fn text_to_value(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, display: [*c]const u8, out: [*c]f64) callconv(.C) bool {
        _ = plugin;
        var index = idToValueIndex(id) catch {
            return false;
        };
        switch (value_metas[index].t) {
            .Bool => {
                const str: []const u8 = std.mem.span(display);
                out.* = if (std.mem.eql(u8, str, "true")) 1.0 else 0.0;
            },
            .VolumeAmp => {
                const str: []const u8 = blk: {
                    var str: []const u8 = std.mem.span(display);
                    str.len = for (str) |char, char_index| {
                        if (char == ' ') {
                            break char_index;
                        }
                    } else new_len: {
                        break :new_len str.len;
                    };
                    break :blk str;
                };
                out.* = util.dBToAmplitude(std.fmt.parseFloat(f32, str) catch @panic("parse float"));
            },
            else => {
                const str: []const u8 = blk: {
                    var str: []const u8 = std.mem.span(display);
                    str.len = for (str) |char, char_index| {
                        if (char == ' ') {
                            break char_index;
                        }
                    } else new_len: {
                        break :new_len str.len;
                    };
                    break :blk str;
                };
                out.* = std.fmt.parseFloat(f32, str) catch @panic("parse float");
            },
        }
        return true;
    }
    fn flush(plugin: [*c]const c.clap_plugin_t, in: [*c]const c.clap_input_events_t, out: [*c]const c.clap_output_events_t) callconv(.C) void {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        var event_index: u32 = 0;
        const num_events = in.*.size.?(in);
        while (event_index < num_events) : (event_index += 1) {
            const event_header = in.*.get.?(in, event_index);
            plug.do_process_event(event_header, out);
        }
    }

    const Data = c.clap_plugin_params_t{
        .count = count,
        .get_info = get_info,
        .get_value = get_value,
        .value_to_text = value_to_text,
        .text_to_value = text_to_value,
        .flush = flush,
    };

    fn serializedSize(_: Params) usize {
        const fields = std.meta.fields(Values);
        var result: usize = @sizeOf(@TypeOf(fields.len));
        result += fields.len * (@sizeOf(u32) + @sizeOf(f64));
        return result;
    }
    fn serialize(self: Params, stream: *const c.clap_ostream_t) !void {
        const fields = std.meta.fields(Values);
        try State.write(stream, fields.len);
        inline for (fields) |field, field_index| {
            try State.write(stream, Params.value_metas[field_index].id);
            try State.write(stream, @field(self.values, field.name));
        }
    }
    fn deserialize(self: *Params, stream: *const c.clap_istream_t) !usize {
        var read_bytes: usize = 0;
        const fields = std.meta.fields(Values);
        const num_values = try State.read(stream, usize);
        read_bytes += @sizeOf(usize);
        var i: usize = 0;
        while (i < num_values) : (i += 1) {
            const id = try State.read(stream, u32);
            read_bytes += @sizeOf(u32);
            inline for (value_metas) |meta, meta_index| {
                if (id == meta.id) {
                    @field(self.values, fields[meta_index].name) = try State.read(stream, f64);
                    read_bytes += @sizeOf(f64);
                    break;
                }
            } else {
                // discard value
                _ = try State.read(stream, f64);
                read_bytes += @sizeOf(f64);
            }
        }
        return read_bytes;
    }

    pub fn setValue(self: *Params, param_id: u32, value: f64) void {
        (self.idToValuePtr(param_id) catch {
            return;
        }).* = value;
    }
    pub fn setValueTellHost(self: *Params, comptime field_name: []const u8, value: f64, time: u32, out_events: *const c.clap_output_events_t) void {
        const param_id = Params.value_metas[@intCast(u32, std.meta.fieldIndex(Params.Values, field_name).?)].id;

        self.setValue(param_id, value);

        var e = c.clap_event_param_value_t{
            .header = .{
                .size = @sizeOf(c.clap_event_param_value_t),
                .space_id = c.CLAP_CORE_EVENT_SPACE_ID,
                .type = c.CLAP_EVENT_PARAM_VALUE,
                .flags = 0,
                .time = time,
            },

            .param_id = param_id,
            .cookie = null,

            .note_id = 0,
            .port_index = 0,
            .channel = 0,
            .key = 0,

            .value = value,
        };

        _ = out_events.*.try_push.?(out_events, &e.header);
    }
};

const NotePorts = struct {
    fn count(plugin: [*c]const c.clap_plugin_t, is_input: bool) callconv(.C) u32 {
        _ = plugin;
        _ = is_input;
        return 1;
    }

    fn get(plugin: [*c]const c.clap_plugin_t, index: u32, is_input: bool, info: [*c]c.clap_note_port_info_t) callconv(.C) bool {
        _ = plugin;
        _ = is_input;
        switch (index) {
            0 => {
                info.* = .{
                    .id = 0,
                    .name = undefined,
                    .supported_dialects = c.CLAP_NOTE_DIALECT_MIDI,
                    .preferred_dialect = c.CLAP_NOTE_DIALECT_MIDI,
                };
                _ = std.fmt.bufPrint(&info.*.name, "Audio Port", .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }

    const Data = c.clap_plugin_note_ports_t{
        .count = count,
        .get = get,
    };
};

const AudioPorts = struct {
    fn count(plugin: [*c]const c.clap_plugin_t, is_input: bool) callconv(.C) u32 {
        _ = plugin;
        _ = is_input;
        return 1;
    }

    fn get(plugin: [*c]const c.clap_plugin_t, index: u32, is_input: bool, info: [*c]c.clap_audio_port_info_t) callconv(.C) bool {
        _ = plugin;
        _ = is_input;
        switch (index) {
            0 => {
                info.* = .{
                    .id = 0,
                    .name = undefined,
                    .channel_count = 2,
                    .flags = c.CLAP_AUDIO_PORT_IS_MAIN,
                    .port_type = &c.CLAP_PORT_STEREO,
                    .in_place_pair = c.CLAP_INVALID_ID,
                };

                _ = std.fmt.bufPrint(&info.*.name, "Audio Port", .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }

    const Data = c.clap_plugin_audio_ports_t{
        .count = count,
        .get = get,
    };
};

const Latency = struct {
    fn get(plugin: [*c]const c.clap_plugin_t) callconv(.C) u32 {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        return plug.*.latency;
    }

    const Data = c.clap_plugin_latency_t{
        .get = get,
    };
};

const State = struct {
    const header: u32 = 0xd40fa068;
    const version: u32 = 0x00000001;

    // state sections (id: u32, size: u64)
    const section_id_params: u32 = 0xFF000001;
    const section_id_gui: u32 = 0xFF000002;

    fn write(stream: *const c.clap_ostream_t, value: anytype) !void {
        if (stream.*.write.?(stream, &value, @sizeOf(@TypeOf(value))) != @sizeOf(@TypeOf(value))) {
            return error.WriteError;
        }
    }
    fn read(stream: *const c.clap_istream_t, comptime T: type) !T {
        var result: T = undefined;
        if (stream.*.read.?(stream, &result, @sizeOf(T)) != @sizeOf(T)) {
            return error.ReadError;
        }
        return result;
    }
    fn readExpect(stream: *const c.clap_istream_t, expect_value: anytype) !void {
        const T = @TypeOf(expect_value);
        var result: T = undefined;
        if (stream.*.read.?(stream, &result, @sizeOf(T)) != @sizeOf(T)) {
            return error.ReadError;
        }
        if (result != expect_value) {
            return error.ReadError;
        }
    }

    fn save(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_ostream_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        saveInner(plug, stream) catch {
            return false;
        };
        return true;
    }

    fn load(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_istream_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        loadInner(plug, stream) catch {
            return false;
        };
        return true;
    }

    fn saveInner(plug: *MyPlugin, stream: [*c]const c.clap_ostream_t) !void {
        try write(stream, header);
        try write(stream, version);

        // number of sections
        try write(stream, @as(u32, 2));

        try write(stream, section_id_params);
        try write(stream, @intCast(u64, plug.params.serializedSize()));
        try plug.params.serialize(stream);

        try write(stream, section_id_gui);
        try write(stream, @intCast(u64, plug.gui.serializedSize()));
        try plug.gui.serialize(stream);
    }
    fn loadInner(plug: *MyPlugin, stream: [*c]const c.clap_istream_t) !void {
        try readExpect(stream, header);
        try readExpect(stream, version);

        var section_index: u32 = 0;
        const sections_len: u32 = try read(stream, u32);

        while (section_index < sections_len) : (section_index += 1) {
            const id = try read(stream, u32);
            const size = try read(stream, u64);

            var read_bytes: usize = 0;
            switch (id) {
                section_id_params => {
                    read_bytes += try plug.params.deserialize(stream);
                },
                section_id_gui => {
                    read_bytes += try plug.gui.deserialize(stream);
                },
                else => {},
            }

            if (read_bytes > size) {
                return error.ReadError;
            }

            while (read_bytes < size) : (read_bytes += 1) {
                _ = try read(stream, u8);
            }
        }
    }

    const Data = c.clap_plugin_state_t{
        .save = save,
        .load = load,
    };
};

pub const MyPlugin = struct {
    plugin: c.clap_plugin_t,
    latency: u32,
    sample_rate: f64 = 44100, // will be overwritten, just don't want this to ever be 0
    tempo: f64 = 120, // (bpm) will be overwritten, just don't want this to ever be 0
    host: [*c]const c.clap_host_t,
    hostParams: [*c]const c.clap_host_params_t,
    hostLog: ?*const c.clap_host_log_t,
    hostLatency: [*c]const c.clap_host_latency_t,
    hostThreadCheck: [*c]const c.clap_host_thread_check_t,
    params: Params = Params{},
    gui: Gui = Gui{},
    platform_gui_data: ?*anyopaque = null,

    const desc = c.clap_plugin_descriptor_t{
        .clap_version = c.clap_version_t{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
        .id = "michael-flaherty.clap-imgui",
        .name = "Clap Imgui",
        .vendor = "Michael Flaherty",
        .url = "https://your-domain.com/your-plugin",
        .manual_url = "https://your-domain.com/your-plugin/manual",
        .support_url = "https://your-domain.com/support",
        .version = "0.0.1",
        .description = "clap plugin using dear imgui for graphics",
        .features = &[_][*c]const u8{
            c.CLAP_PLUGIN_FEATURE_INSTRUMENT,
            c.CLAP_PLUGIN_FEATURE_STEREO,
            null,
        },
    };

    fn init(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);

        // Fetch host's extensions here
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_LOG);
            if (ptr != null) {
                plug.*.hostLog = c_cast(*const c.clap_host_log_t, ptr);
                plug.*.hostLog.?.*.log.?(plug.*.host, c.CLAP_LOG_DEBUG, "this is something I am logging");
            }
        }
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_THREAD_CHECK);
            if (ptr != null) {
                plug.*.hostThreadCheck = c_cast(*const c.clap_host_thread_check_t, ptr);
            }
        }
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_LATENCY);
            if (ptr != null) {
                plug.*.hostLatency = c_cast(*const c.clap_host_latency_t, ptr);
            }
        }
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_PARAMS);
            if (ptr != null) {
                plug.*.hostParams = c_cast(*const c.clap_host_params_t, ptr);
            }
        }

        return true;
    }

    fn destroy(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        global.allocator.destroy(c_cast(*MyPlugin, plugin.*.plugin_data));
    }

    fn activate(plugin: [*c]const c.clap_plugin_t, sample_rate: f64, min_frames_count: u32, max_frames_count: u32) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        plug.sample_rate = sample_rate;
        _ = min_frames_count;
        _ = max_frames_count;
        return true;
    }

    fn deactivate(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }

    fn start_processing(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        _ = plugin;
        return true;
    }

    fn stop_processing(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }

    fn reset(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }
    fn on_main_thread(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }

    fn get_extension(plugin: [*c]const c.clap_plugin_t, id: [*c]const u8) callconv(.C) ?*const anyopaque {
        _ = plugin;
        if (c.strcmp(id, &c.CLAP_EXT_LATENCY) == 0)
            return &Latency.Data;
        if (c.strcmp(id, &c.CLAP_EXT_AUDIO_PORTS) == 0)
            return &AudioPorts.Data;
        if (c.strcmp(id, &c.CLAP_EXT_NOTE_PORTS) == 0)
            return &NotePorts.Data;
        if (c.strcmp(id, &c.CLAP_EXT_PARAMS) == 0)
            return &Params.Data;
        if (c.strcmp(id, &c.CLAP_EXT_STATE) == 0)
            return &State.Data;
        if (c.strcmp(id, &c.CLAP_EXT_GUI) == 0)
            return &Gui.Data;
        return null;
    }

    fn create(host: [*c]const c.clap_host_t) [*c]c.clap_plugin_t {
        var p = global.allocator.create(MyPlugin) catch unreachable;
        p.* = .{
            .plugin = .{
                .desc = &desc,
                .plugin_data = p,
                .init = init,
                .destroy = destroy,
                .activate = activate,
                .deactivate = deactivate,
                .start_processing = start_processing,
                .stop_processing = stop_processing,
                .reset = reset,
                .process = do_process,
                .get_extension = get_extension,
                .on_main_thread = on_main_thread,
            },
            .host = host,
            .hostParams = null,
            .hostLatency = null,
            .hostLog = null,
            .hostThreadCheck = null,
            .latency = 0,
        };
        // Don't call into the host here
        return &p.plugin;
    }

    var x_n_minus_1: [2]f32 = [2]f32{
        0.0,
        0.0,
    };
    var x_n_minus_2: [2]f32 = [2]f32{
        0.0,
        0.0,
    };
    var y_n_minus_1: [2]f32 = [2]f32{
        0.0,
        0.0,
    };
    var y_n_minus_2: [2]f32 = [2]f32{
        0.0,
        0.0,
    };

    var on_sample: usize = 0;
    var play: bool = false;
    var bypass_filter: bool = false;
    var block_sample_start: usize = 0;
    var on_block_sample: usize = 0;

    fn do_process(plugin: [*c]const c.clap_plugin_t, process: [*c]const c.clap_process_t) callconv(.C) c.clap_process_status {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);

        plug.tempo = process.*.transport.*.tempo;

        const pos_seconds = @intToFloat(f64, process.*.transport.*.song_pos_seconds) / @intToFloat(f64, @as(i64, 1 << 31));
        block_sample_start = @floatToInt(usize, std.math.round(pos_seconds * plug.sample_rate));
        on_block_sample = 0;

        const num_frames = process.*.frames_count;
        const num_events = process.*.in_events.*.size.?(process.*.in_events);

        var frame_index: u32 = 0;
        var event_index: u32 = 0;
        var next_event_frame: u32 = if (num_events > 0) @as(u32, 0) else num_frames;

        while (frame_index < num_frames) {
            handle_events: while (event_index < num_events and frame_index == next_event_frame) {
                const event_header = process.*.in_events.*.get.?(process.*.in_events, event_index);

                if (event_header.*.time != frame_index) {
                    next_event_frame = event_header.*.time;
                    break :handle_events;
                }

                do_process_event(plug, event_header, process.*.out_events);
                event_index += 1;

                if (event_index == num_events) {
                    next_event_frame = num_frames;
                }
            }

            const gain_main = @floatCast(f32, plug.params.values.gain_amplitude_main);
            const a0 = @floatCast(f32, plug.params.values.a0);
            const a1 = @floatCast(f32, plug.params.values.a1);
            const a2 = @floatCast(f32, plug.params.values.a2);
            const b1 = @floatCast(f32, plug.params.values.b1);
            const b2 = @floatCast(f32, plug.params.values.b2);

            while (frame_index < next_event_frame) : (frame_index += 1) {
                // generate noise
                const x_n_0 = util.randAmplitudeValue() * gain_main;
                const x_n_1 = if (plug.params.values.stereo == 0.0) x_n_0 else util.randAmplitudeValue() * gain_main;
                const x_n = [2]f32{
                    x_n_0,
                    x_n_1,
                };

                // biquad filter
                var y_n = [2]f32{
                    (x_n[0] * a0) + (x_n_minus_1[0] * a1) + (x_n_minus_2[0] * a2) - (y_n_minus_1[0] * b1) - (y_n_minus_2[0] * b2),
                    (x_n[1] * a0) + (x_n_minus_1[1] * a1) + (x_n_minus_2[1] * a2) - (y_n_minus_1[1] * b1) - (y_n_minus_2[1] * b2),
                };

                if (bypass_filter) {
                    process.*.audio_outputs[0].data32[0][frame_index] = x_n[0];
                    process.*.audio_outputs[0].data32[1][frame_index] = x_n[1];
                } else {
                    process.*.audio_outputs[0].data32[0][frame_index] = y_n[0];
                    process.*.audio_outputs[0].data32[1][frame_index] = y_n[1];
                }

                on_sample += 1;

                x_n_minus_2 = x_n_minus_1;
                x_n_minus_1 = x_n;

                y_n_minus_2 = y_n_minus_1;
                y_n_minus_1 = y_n;
            }

            on_block_sample += 1;
        }

        return c.CLAP_PROCESS_SLEEP;
    }

    fn do_process_event(plug: *MyPlugin, hdr: [*c]const c.clap_event_header_t, out_events: *const c.clap_output_events_t) void {
        _ = out_events;
        if (hdr.*.space_id == c.CLAP_CORE_EVENT_SPACE_ID) {
            switch (hdr.*.type) {
                c.CLAP_EVENT_PARAM_VALUE => {
                    const ev = c_cast([*c]const c.clap_event_param_value_t, hdr);
                    plug.params.setValue(ev.*.param_id, ev.*.value);
                },
                c.CLAP_EVENT_TRANSPORT => {
                    const ev = c_cast([*c]const c.clap_event_transport_t, hdr);
                    plug.tempo = ev.*.tempo;
                },
                else => {},
            }
        }
    }
};

const Factory = struct {
    fn get_plugin_count(factory: [*c]const c.clap_plugin_factory_t) callconv(.C) u32 {
        _ = factory;
        return 1;
    }
    fn get_plugin_descriptor(factory: [*c]const c.clap_plugin_factory_t, index: u32) callconv(.C) [*c]const c.clap_plugin_descriptor_t {
        _ = factory;
        _ = index;
        return &MyPlugin.desc;
    }
    fn create_plugin(factory: [*c]const c.clap_plugin_factory_t, host: [*c]const c.clap_host_t, plugin_id: [*c]const u8) callconv(.C) [*c]const c.clap_plugin_t {
        _ = factory;
        if (!clap_version_is_compatible(host.*.clap_version)) {
            return null;
        }
        if (std.cstr.cmp(plugin_id, MyPlugin.desc.id) == 0) {
            return MyPlugin.create(host);
        }
        return null;
    }
    const Data = c.clap_plugin_factory_t{
        .get_plugin_count = Factory.get_plugin_count,
        .get_plugin_descriptor = Factory.get_plugin_descriptor,
        .create_plugin = Factory.create_plugin,
    };
};

pub fn clap_version_is_compatible(v: c.clap_version_t) bool {
    return v.major >= 1;
}

const Entry = struct {
    fn init(plugin_path: [*c]const u8) callconv(.C) bool {
        _ = plugin_path;

        // this is my current best idea on how to read logging
        // reaper has hostLog extension, but I don't know how that works
        if (builtin.mode == .Debug and builtin.os.tag == .windows) {
            c.redirectStdOutToConsoleWindow();
        }

        global.init();
        return true;
    }
    fn deinit() callconv(.C) void {}
    fn get_factory(factory_id: [*c]const u8) callconv(.C) ?*const anyopaque {
        if (std.cstr.cmp(factory_id, &c.CLAP_PLUGIN_FACTORY_ID) == 0) {
            return &Factory.Data;
        }
        return null;
    }
};

export const clap_entry = c.clap_plugin_entry_t{
    .clap_version = c.clap_version_t{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
    .init = &Entry.init,
    .deinit = &Entry.deinit,
    .get_factory = &Entry.get_factory,
};
