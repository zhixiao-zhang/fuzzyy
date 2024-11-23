vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/devicons.vim'

var buf_dict: dict<any>
var key_callbacks: dict<any>
var _windows: dict<any>
var devicon_char_width = devicons.GetDeviconCharWidth()

# Options
var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')

var keymaps = {
    'delete_buffer': "",
    'close_buffer': "\<c-l>",
}
if exists('g:fuzzyy_buffers_keymap')
    keymaps->extend(g:fuzzyy_buffers_keymap, 'force')
endif

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if result == ''
        return
    endif
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    if enable_devicons
        result = strcharpart(result, devicon_char_width + 1)
    endif
    var file: string
    var lnum: number
    try
        file = buf_dict[result][0]
        lnum = buf_dict[result][2]
    catch
        echom 'Error FuzzyBuffer - Preview: buffer not found'
        echom [buf_dict, result]
    endtry
    if !filereadable(file)
        if file == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, file .. ' not found')
        endif
        return
    endif
    var bufnr = buf_dict[result][1]
    var ft = getbufvar(bufnr, '&filetype')
    var fileraw = readfile(file, '')
    var preview_bufnr = winbufnr(preview_wid)
    popup_settext(preview_wid, fileraw)
    try
        setbufvar(preview_bufnr, '&syntax', ft)
    catch
    endtry
    win_execute(preview_wid, 'norm! ' .. lnum .. 'G')
    win_execute(preview_wid, 'norm! zz')
enddef

def Close(wid: number, result: dict<any>)
    if has_key(result, 'selected_item')
        var buf = result.selected_item
        if enable_devicons
            buf = strcharpart(buf, devicon_char_width + 1)
        endif
        var bufnr = buf_dict[buf][1]
        if bufnr != bufnr('$')
            execute 'buffer' bufnr
        endif
    endif
enddef

def GetBufList(): list<string>
    var buf_data = getbufinfo({'buflisted': 1, 'bufloaded': 0})
    buf_dict = {}

    var exclude_buffers = exists('g:fuzzyy_buffers_exclude') ?
        g:fuzzyy_buffers_exclude : []

    reduce(buf_data, (acc, buf) => {
        if index(exclude_buffers, fnamemodify(buf.name, ':t')) >= 0
        || buf.name == ''
            return acc
        endif
        var file = fnamemodify(buf.name, ":~:.")
        if len(file) > _windows.width / 2 * &columns
            file = pathshorten(file)
        endif
        acc[file] = [buf.name, buf.bufnr, buf.lnum, buf.lastused]
        return acc
    }, buf_dict)

    var bufs = keys(buf_dict)->sort((a, b) => {
        return buf_dict[a][3] == buf_dict[b][3] ? 0 :
               buf_dict[a][3] <  buf_dict[b][3] ? 1 : -1
    })
    return bufs
enddef

def DeleteSelectedBuffer()
    var buf = selector.MenuGetCursorItem(true)
    delete(buf)
enddef
def CloseSelectedBuffer()
    var buf = selector.MenuGetCursorItem(true)
    execute(':bw ' .. buf)
    selector.UpdateMenu(GetBufList(), [], 1)
enddef

key_callbacks[keymaps.delete_buffer] = function("DeleteSelectedBuffer")
key_callbacks[keymaps.close_buffer] = function("CloseSelectedBuffer")

export def Start(windows: dict<any>)
    _windows = windows

    var wids = selector.Start(GetBufList(), {
        preview_cb:  function('Preview'),
        close_cb:  function('Close'),
        dropdown: 0,
        preview: _windows.preview,
        width: _windows.width,
        preview_ratio: _windows.preview_ratio,
        scrollbar: 0,
        enable_devicons: enable_devicons,
        key_callbacks: extend(selector.split_edit_callbacks, key_callbacks),
    })
enddef
