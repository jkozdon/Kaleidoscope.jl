@enum _Token begin
    tok_eof = -1

    # commands
    tok_def = -2
    tok_extern = -3

    # primary
    tok_identifier = -4
    tok_number = -5

    # misc
    tok_misc = -6
end

struct Token
    tok::_Token
    val::String
end

mutable struct Lexer{T}
    fid::T
    last::Char
    next::Token
    function Lexer(filename::String)
        fid = open(filename, "r")
        last = read(fid, Char)
        next = Token(tok_misc, "")
        lex = new{typeof(fid)}(fid, last, next)
        gettok!(lex)
        return lex
    end
end

function gettok!(lex)
    curtok = lex.next
    lex.next = getnexttok!(lex)
    return curtok
end

function getnexttok!(lex)
    buf = IOBuffer()

    # Clear whitespace
    while isspace(lex.last)
        # Check if to continue or at end of file
        eof(lex.fid) && return Token(tok_eof, "")
        lex.last = read(lex.fid, Char)
    end

    # Check if to continue or at end of file
    eof(lex.fid) && return Token(tok_eof, "")

    # Clear comment
    if lex.last == '#'
        lex.last = read(lex.fid, Char)
        while lex.last != '\n' && lex.last != '\r'
            # Check if to continue or at end of file
            eof(lex.fid) && break
            lex.last = read(lex.fid, Char)
        end
        return gettok!(lex)
    elseif isdigit(lex.last) # get a number
        write(buf, lex.last)
        while !eof(lex.fid)
            lex.last = read(lex.fid, Char)
            !(isdigit(lex.last) || lex.last == '.') && break
            write(buf, lex.last)
        end
        return Token(tok_number, String(take!(buf)))
    elseif isletter(lex.last) # get an identifier / def / extern
        write(buf, lex.last)
        while !eof(lex.fid)
            lex.last = read(lex.fid, Char)
            !(isdigit(lex.last) || isletter(lex.last)) && break
            write(buf, lex.last)
        end
        val = String(take!(buf))
        tok = if val == "def"
            tok_def
        elseif val == "extern"
            tok_extern
        else
            tok_identifier
        end
        return Token(tok, val)
    else # Something else!
        t = Token(tok_misc, "$(lex.last)")
        lex.last = read(lex.fid, Char)
        return t
    end
end
