const std = @import("std");

pub fn ResourceBuffer(T: type) type {
    return struct {
        const Self = @This();

        pub const Handle = struct {
            id: u32,

            // Needed to make sure that the handle is unique for each different type
            comptime {
                const T1 = T;
                _ = T1;
            }
        };

        const Id = packed struct(u32) {
            index: u20,
            version: u12,
        };

        allocator: std.mem.Allocator,
        sparse: []Id,
        dense: []Id,
        items: []T,
        available: u32,
        count: u32,

        pub fn init(allocator: std.mem.Allocator, size: u32) !Self {
            var self = Self{
                .allocator = allocator,
                .sparse = try allocator.alloc(Id, size),
                .dense = try allocator.alloc(Id, size),
                .items = try allocator.alloc(T, size),
                .count = 0,
                .available = 0,
            };

            // Set up free slots
            for (self.sparse, 0..) |*entry, i| {
                entry.index = @intCast(i + 1);
                entry.version = 0;
            }

            self.sparse[size - 1].index = 0;

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.dense);
            self.allocator.free(self.sparse);
            self.allocator.free(self.items);
            self.count = 0;
        }

        pub fn allocHandle(self: *Self) !Handle {
            if (self.count >= self.dense.len) return error.OutOfCapacity;

            const index = self.available;
            const sparse_item = self.sparse[index];

            const sparse_id = Id{
                .index = @intCast(self.count),
                .version = sparse_item.version,
            };

            const dense_id = Id{
                .index = @intCast(index),
                .version = sparse_item.version,
            };

            self.available = @intCast(sparse_item.index);

            self.sparse[index] = sparse_id;
            self.dense[self.count] = dense_id;

            self.count += 1;

            return .{ .id = @bitCast(dense_id) };
        }

        pub fn alloc(self: *Self, item_out: **T) !Handle {
            if (self.count >= self.dense.len) return error.OutOfCapacity;

            const index = self.available;
            const sparse_item = self.sparse[index];

            const sparse_id = Id{
                .index = @intCast(self.count),
                .version = sparse_item.version,
            };

            const dense_id = Id{
                .index = @intCast(index),
                .version = sparse_item.version,
            };

            self.available = @intCast(sparse_item.index);

            self.sparse[index] = sparse_id;
            self.dense[self.count] = dense_id;

            self.count += 1;

            item_out.* = &self.items[sparse_id.index];

            return .{ .id = @bitCast(dense_id) };
        }

        pub fn dealloc(self: *Self, handle: Handle) void {
            const id: Id = @bitCast(handle.id);

            std.debug.assert(id.index <= self.sparse.len);

            const dense_index: u20 = self.sparse[id.index].index;

            // Assert on possible double free
            std.debug.assert(dense_index <= self.count);

            // Wrap around if max version is achieved
            const dense_version: u12 = self.sparse[id.index].version +% 1;

            self.dense[dense_index].version = dense_version;

            self.sparse[id.index] = Id{
                .index = @intCast(self.available),
                .version = dense_version,
            };

            self.available = @intCast(id.index);

            // Remove element from dense
            const last_index = self.count - 1;

            if (dense_index != last_index) {
                const last_id = self.dense[last_index];
                self.items[dense_index] = self.items[last_index];
                self.dense[dense_index] = last_id;
                self.sparse[last_id.index].index = dense_index;
            }

            self.count -= 1;
        }

        // return without safety check, only debug asserts
        pub fn at(self: *Self, handle: Handle) *T {
            const id: Id = @bitCast(handle.id);
            const index = id.index;

            std.debug.assert(index <= self.sparse.len);

            const sparse_entry = self.sparse[id.index];

            std.debug.assert(handle.id == @as(u32, @bitCast(self.dense[sparse_entry.index])));

            return &self.items[sparse_entry.index];
        }

        // return with safety check, checks if handle matches the one in storage
        pub fn get(self: *Self, handle: Handle) ?*T {
            const id: Id = @bitCast(handle.id);
            const index = id.index;

            std.debug.assert(index <= self.sparse.len);

            const sparse_entry = self.sparse[id.index];

            if (handle.id == @as(u32, @bitCast(self.dense[sparse_entry.index]))) {
                return &self.items[sparse_entry.index];
            }

            return null;
        }

        pub fn contains(self: *Self, handle: Handle) bool {
            const id: Id = @bitCast(handle.id);
            const index = id.index;

            if (index >= self.sparse.len) return false;

            const sparse_entry = self.sparse[id.index];
            const dense_entry = self.dense[sparse_entry.index];

            return @as(u32, @bitCast(dense_entry)) == handle.id;
        }

        pub fn getDenseIndex(self: *Self, handle: Handle) u32 {
            const id: Id = @bitCast(handle.id);
            return self.sparse[id.index].index;
        }

        pub fn getAll(self: *Self) []T {
            return self.items[0..self.count];
        }
    };
}

pub fn ResourceBufferUnmanaged(T: type) type {
    return struct {
        const Self = @This();

        pub const Handle = struct {
            id: u32,

            // Needed to make sure that the handle is unique for each different type
            comptime {
                const T1 = T;
                _ = T1;
            }
        };

        const Id = packed struct(u32) {
            index: u20,
            version: u12,
        };

        sparse: []Id,
        dense: []Id,
        items: []T,
        available: u32,
        count: u32,

        pub fn init(allocator: std.mem.Allocator, size: u32) !Self {
            var self = Self{
                .sparse = try allocator.alloc(Id, size),
                .dense = try allocator.alloc(Id, size),
                .items = try allocator.alloc(T, size),
                .count = 0,
                .available = 0,
            };

            // Set up free slots
            for (self.sparse, 0..) |*entry, i| {
                entry.index = @intCast(i + 1);
                entry.version = 0;
            }
            self.sparse[size - 1].index = 0;

            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.dense);
            allocator.free(self.sparse);
            allocator.free(self.items);
            self.count = 0;
        }

        pub fn allocHandle(self: *Self) !Handle {
            if (self.count >= self.dense.len) return error.OutOfCapacity;

            const index = self.available;
            const sparse_item = self.sparse[index];

            const sparse_id = Id{
                .index = @intCast(self.count),
                .version = sparse_item.version,
            };

            const dense_id = Id{
                .index = @intCast(index),
                .version = sparse_item.version,
            };

            self.available = @intCast(sparse_item.index);

            self.sparse[index] = sparse_id;
            self.dense[self.count] = dense_id;

            self.count += 1;

            return .{ .id = @bitCast(dense_id) };
        }

        pub fn alloc(self: *Self, item_out: **T) !Handle {
            if (self.count >= self.dense.len) return error.OutOfCapacity;

            const index = self.available;
            const sparse_item = self.sparse[index];

            const sparse_id = Id{
                .index = @intCast(self.count),
                .version = sparse_item.version,
            };

            const dense_id = Id{
                .index = @intCast(index),
                .version = sparse_item.version,
            };

            self.available = @intCast(sparse_item.index);

            self.sparse[index] = sparse_id;
            self.dense[self.count] = dense_id;

            self.count += 1;

            item_out.* = &self.items[sparse_id.index];

            return .{ .id = @bitCast(dense_id) };
        }

        pub fn dealloc(self: *Self, handle: Handle) void {
            const id: Id = @bitCast(handle.id);

            std.debug.assert(id.index <= self.sparse.len);

            const dense_index: u20 = self.sparse[id.index].index;

            // Assert on possible double free
            std.debug.assert(dense_index <= self.count);

            // Wrap around if max version is achieved
            const dense_version: u12 = self.sparse[id.index].version +% 1;

            self.dense[dense_index].version = dense_version;

            self.sparse[id.index] = Id{
                .index = @intCast(self.available),
                .version = dense_version,
            };

            self.available = @intCast(id.index);

            // Remove element from dense
            const last_index = self.count - 1;

            if (dense_index != last_index) {
                const last_id = self.dense[last_index];
                self.items[dense_index] = self.items[last_index];
                self.dense[dense_index] = last_id;
                self.sparse[last_id.index].index = dense_index;
            }

            self.count -= 1;
        }

        // return without safety check, only debug asserts
        pub fn at(self: *Self, handle: Handle) *T {
            const id: Id = @bitCast(handle.id);
            const index = id.index;

            std.debug.assert(index <= self.sparse.len);

            const sparse_entry = self.sparse[id.index];

            std.debug.assert(handle.id == @as(u32, @bitCast(self.dense[sparse_entry.index])));

            return &self.items[sparse_entry.index];
        }

        // return with safety check, checks if handle matches the one in storage
        pub fn get(self: *Self, handle: Handle) ?*T {
            const id: Id = @bitCast(handle.id);
            const index = id.index;

            std.debug.assert(index <= self.sparse.len);

            const sparse_entry = self.sparse[id.index];

            if (handle.id == @as(u32, @bitCast(self.dense[sparse_entry.index]))) {
                return &self.items[sparse_entry.index];
            }

            return null;
        }

        pub fn contains(self: *Self, handle: Handle) bool {
            const id: Id = @bitCast(handle.id);
            const index = id.index;

            if (index >= self.sparse.len) return false;

            const sparse_entry = self.sparse[id.index];
            const dense_entry = self.dense[sparse_entry.index];

            return @as(u32, @bitCast(dense_entry)) == handle.id;
        }

        pub fn getDenseIndex(self: *Self, handle: Handle) u32 {
            const id: Id = @bitCast(handle.id);
            return self.sparse[id.index].index;
        }

        pub fn getAll(self: *Self) []T {
            return self.items[0..self.count];
        }
    };
}

test "ResourceBuffer(T).init sets correct defaults" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBuffer(usize).init(allocator, 16);
    defer buff.deinit();

    try testing.expectEqual(0, buff.count);
    try testing.expectEqual(0, buff.available);
    try testing.expectEqual(16, buff.sparse.len);
    try testing.expectEqual(16, buff.items.len);
    try testing.expectEqual(16, buff.dense.len);
}

test "ResourceBufferUnmanaged(T).init sets correct defaults" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBufferUnmanaged(usize).init(allocator, 16);
    defer buff.deinit(allocator);

    try testing.expectEqual(0, buff.count);
    try testing.expectEqual(0, buff.available);
    try testing.expectEqual(16, buff.sparse.len);
    try testing.expectEqual(16, buff.items.len);
    try testing.expectEqual(16, buff.dense.len);
}

test "ResourceBuffer(T).alloc returns correct handle" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBuffer(usize).init(allocator, 16);
    defer buff.deinit();

    const handle = try buff.allocHandle();

    try testing.expectEqual(0, buff.getDenseIndex(handle));
    try testing.expectEqual(1, buff.count);
    try testing.expectEqual(1, buff.available);
    try testing.expectEqual(16, buff.sparse.len);
    try testing.expectEqual(16, buff.items.len);
    try testing.expectEqual(16, buff.dense.len);
}

test "ResourceBufferUnmanaged(T).alloc returns correct handle" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var buff = try ResourceBufferUnmanaged(usize).init(allocator, 16);
    defer buff.deinit(allocator);
    const handle = try buff.allocHandle();

    try testing.expectEqual(0, buff.getDenseIndex(handle));
    try testing.expectEqual(1, buff.count);
    try testing.expectEqual(1, buff.available);
    try testing.expectEqual(16, buff.sparse.len);
    try testing.expectEqual(16, buff.items.len);
    try testing.expectEqual(16, buff.dense.len);
}

test "ResourceBuffer(T).contains returns if alloc handle is valid" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBuffer(usize).init(allocator, 16);
    defer buff.deinit();

    const handle = try buff.allocHandle();

    try testing.expectEqual(0, buff.getDenseIndex(handle));
    try testing.expect(buff.contains(handle));
}

test "ResourceBufferUnmanaged(T).contains returns if alloc handle is valid" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBufferUnmanaged(usize).init(allocator, 16);
    defer buff.deinit(allocator);

    const handle = try buff.allocHandle();

    try testing.expectEqual(0, buff.getDenseIndex(handle));
    try testing.expect(buff.contains(handle));
}

test "ResourceBuffer(T).dealloc deallocates handle and invalidates it" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBuffer(usize).init(allocator, 16);
    defer buff.deinit();

    const handle = try buff.allocHandle();
    const handle1 = try buff.allocHandle();

    try testing.expectEqual(0, buff.getDenseIndex(handle));
    try testing.expect(buff.contains(handle));
    try testing.expectEqual(1, buff.getDenseIndex(handle1));
    try testing.expect(buff.contains(handle1));

    buff.dealloc(handle);

    try testing.expect(!buff.contains(handle));
    try testing.expect(buff.contains(handle1));

    buff.dealloc(handle1);

    try testing.expect(!buff.contains(handle));
    try testing.expect(!buff.contains(handle1));
}

test "ResourceBufferUnmanaged(T).dealloc deallocate handle and invalidates it" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buff = try ResourceBufferUnmanaged(usize).init(allocator, 16);
    defer buff.deinit(allocator);

    const handle = try buff.allocHandle();
    const handle1 = try buff.allocHandle();

    try testing.expectEqual(0, buff.getDenseIndex(handle));
    try testing.expect(buff.contains(handle));
    try testing.expectEqual(1, buff.getDenseIndex(handle1));
    try testing.expect(buff.contains(handle1));

    buff.dealloc(handle);

    try testing.expect(!buff.contains(handle));
    try testing.expect(buff.contains(handle1));

    buff.dealloc(handle1);

    try testing.expect(!buff.contains(handle));
    try testing.expect(!buff.contains(handle1));
}

test "ResourceBuffer(T).at returns resource from handle if valid" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const size = 16;
    var buff = try ResourceBuffer(usize).init(allocator, size);
    defer buff.deinit();

    for (0..size) |i| {
        const handle = try buff.allocHandle();
        const value = buff.at(handle);
        value.* = i;
    }

    try testing.expectEqual(size, buff.count);

    for (buff.items, 0..) |value, i| {
        try testing.expectEqual(i, value);
    }
}

test "ResourceBufferUnmanaged(T).at returns resource from handle if valid" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const size = 16;
    var buff = try ResourceBufferUnmanaged(usize).init(allocator, size);
    defer buff.deinit(allocator);

    for (0..size) |i| {
        const handle = try buff.allocHandle();
        const value = buff.at(handle);
        value.* = i;
    }

    try testing.expectEqual(size, buff.count);

    for (buff.items, 0..) |value, i| {
        try testing.expectEqual(i, value);
    }
}

test "ResourceBuffer(T).get returns resource from handle if valid" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const size = 16;

    var buff = try ResourceBuffer(usize).init(allocator, size);
    defer buff.deinit();

    for (0..size) |i| {
        const handle = try buff.allocHandle();
        const value = buff.get(handle);
        value.?.* = i;
    }

    try testing.expectEqual(size, buff.count);

    for (buff.items, 0..) |value, i| {
        try testing.expectEqual(i, value);
    }
}

test "ResourceBufferUnmanaged(T).get returns resource from handle if valid" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const size = 16;
    var buff = try ResourceBufferUnmanaged(usize).init(allocator, size);
    defer buff.deinit(allocator);

    for (0..size) |i| {
        const handle = try buff.allocHandle();
        const value = buff.get(handle);
        value.?.* = i;
    }

    try testing.expectEqual(size, buff.count);

    for (buff.items, 0..) |value, i| {
        try testing.expectEqual(i, value);
    }
}

test "ResourceBuffer(T).get returns null from handle if invalid" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const size = 16;

    var buff = try ResourceBuffer(usize).init(allocator, size);
    defer buff.deinit();

    const handle = try buff.allocHandle();
    const handle1 = try buff.allocHandle();
    const handle2 = try buff.allocHandle();

    buff.at(handle).* = 0;
    buff.at(handle1).* = 1;
    buff.at(handle2).* = 2;

    buff.dealloc(handle1);

    const value = buff.get(handle);
    const value1 = buff.get(handle1);
    const value2 = buff.get(handle2);

    try testing.expectEqual(0, value.?.*);
    try testing.expectEqual(null, value1);
    try testing.expectEqual(2, value2.?.*);
}

test "ResourceBufferUnmanaged(T).get returns null from handle if invalid" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const size = 16;
    var buff = try ResourceBufferUnmanaged(usize).init(allocator, size);
    defer buff.deinit(allocator);

    const handle = try buff.allocHandle();
    const handle1 = try buff.allocHandle();
    const handle2 = try buff.allocHandle();

    buff.at(handle).* = 0;
    buff.at(handle1).* = 1;
    buff.at(handle2).* = 2;

    buff.dealloc(handle1);

    const value = buff.get(handle);
    const value1 = buff.get(handle1);
    const value2 = buff.get(handle2);

    try testing.expectEqual(0, value.?.*);
    try testing.expectEqual(null, value1);
    try testing.expectEqual(2, value2.?.*);
}
