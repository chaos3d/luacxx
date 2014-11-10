#!/usr/bin/env ruby
require "ffi/clang"

index = FFI::Clang::Index.new
file = "src/action/action_keyframe.h"
#file = "src/asset_support/texture_asset.h"
#file = "src/common/log.h"

xcode_path = `xcode-select -p`.strip
sysroot = `xcrun --show-sdk-path`.strip
includes = [
    "#{xcode_path}/Toolchains/XcodeDefault.xctoolchain/usr/bin/../include/c++/v1", 
    "#{xcode_path}/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/clang/6.0/include",
    "src"
]

sysroots = [
    "external"
]

p ["-x", "c++", "-std=c++11", "-isysroot", sysroot] \
        + includes.map { |i| "-I" + i } \
        + ["-isystem"].product(sysroots).flatten

translation_unit = index.parse_translation_unit file, ["-x", "c++", "-std=c++11", "-isysroot", sysroot] +
    includes.map { |i| "-I" + i } + 
    ["-isystem"].product(sysroots).flatten

stack = 1
visitor = Proc.new do |cursor, parent|

    prefix = (" + " * stack)
    if cursor.num_arguments > 0 then
        puts prefix + " args:" + cursor.kind.to_s + ", " + cursor.spelling.to_s + ":" + cursor.num_arguments.to_s;
    end
    if cursor.kind == :cursor_function_template then
        puts prefix + " func template:" + cursor.num_arguments.to_s
        for i in 0..cursor.num_arguments
            puts(translation_unit.tokenize cursor.arguments[i].extent)
        end
    elsif cursor.kind == :cursor_parm_decl then
        puts prefix + " " + cursor.kind.to_s + "," + cursor.spelling.to_s
    else
        puts prefix + " new:" + cursor.kind.to_s + "," + cursor.spelling.to_s
    end
    if cursor.comment then
        cursor.comment.each {|e| puts "#{e.kind}: #{e.respond_to?(:name) and e.name} #{e.text}" }
    end
end

adapter = nil;
adapter = Proc.new do |cursor, parent|
    next :continue if not cursor.location.from_main_file?;
    visitor.call cursor, parent
    stack += 1
    cursor.visit_children &adapter
    stack -= 1
    next :continue
end

visitor.call(translation_unit.cursor)
translation_unit.cursor.visit_children &adapter
translation_unit.diagnostics.each do |e| p e.format end
