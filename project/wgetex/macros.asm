comment * -----------------------------------------------------------------
        Preprocessor code for high level language simulation in MASM32

                          Updated 2nd December 2011
         ---------------------------------------------------------------- *

  ; *******************************************************************
  ; The following block of macros are macro functions that are designed
  ; to be called by other macros. In part they function as a library of
  ; components for writing other macros without having to repeatedly
  ; reproduce the same capacity. Effectively macro code reuse.
  ; *******************************************************************

  ; -----------------------------------------------------------
  ; This macro replaces quoted text with a DATA section OFFSET
  ; and returns it in OFFSET "name" format. It is used by other
  ; macros that handle optional quoted text as a parameter.
  ; NOTE that while this macro behaves identically on single
  ; byte characters, it now supports 2 byte characters if the
  ; __UNICODE__ equate is set.
  ; -----------------------------------------------------------
    reparg MACRO arg
      LOCAL nustr
      LOCAL quot
        quot SUBSTR <arg>,1,1
      IFIDN quot,<">                ;; if 1st char = "

        IFNDEF __UNICODE__
          .data
            nustr db arg,0          ;; write arg to .DATA section
          .code
          EXITM <OFFSET nustr>      ;; append name to OFFSET operator
        ELSE
          EXITM <uni$(arg)>         ;; use the "uni$()" macro
        ENDIF

      ELSE
        EXITM <arg>                 ;; else return arg
      ENDIF
    ENDM

  ; -------------------------------------
  ; variation returns address in register
  ; so it can be assigned to a variable.
  ; -------------------------------------
    repargv MACRO arg
      LOCAL nustr
        quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        .data
          nustr db arg,0        ;; write arg to .DATA section
        .code
        mov eax, OFFSET nustr
        EXITM <eax>             ;; return data section offset in eax
      ELSE
        mov eax, arg
        EXITM <eax>             ;; else return arg
      ENDIF
    ENDM

  ; -----------------------------------------------------------
  ; replace a quoted string with its OFFSET in the data section
  ; -----------------------------------------------------------
    repargof MACRO arg
      LOCAL nustr
        quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        .data
          nustr db arg,0        ;; write arg to .DATA section
        .code
        EXITM <OFFSET nustr>    ;; append name to OFFSET operator
      ELSE
        EXITM <arg>             ;; else return arg
      ENDIF
    ENDM

  ; -------------------------------------------------------
  ; This is a parameter checking macro. It is used to test
  ; if a parameter in a macro is a quoted string when a
  ; quoted string should not be used as a parameter. If it
  ; is a user defined error message is displayed at
  ; assembly time so that the error can be fixed.
  ; -------------------------------------------------------
    tstarg MACRO arg
      quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        % echo *****************
        % echo QUOTED TEXT ERROR
        % echo *****************
        % echo argument = arg
        % echo valid memory buffer address required
        % echo *****************
        .ERR
        EXITM <arg>
      ELSE
        EXITM <arg>             ;; else return arg
      ENDIF
    ENDM

  ; -----------------------------------------------
  ; count the number of arguments passed to a macro
  ; This is a slightly modified 1990 MASM 6.0 macro
  ; -----------------------------------------------
    argcount MACRO args:VARARG
      LOCAL cnt
      cnt = 0
      FOR item, <args>
        cnt = cnt + 1
      ENDM
      EXITM %cnt                ;; return as a number
    ENDM

  ; ---------------------------------------------------
  ; return an arguments specified in "num" from a macro
  ; argument list or "-1" if the number is out of range
  ; ---------------------------------------------------
    getarg MACRO num:REQ,args:VARARG
      LOCAL cnt, txt
      cnt = 0
      FOR arg, <args>
        cnt = cnt + 1
        IF cnt EQ num
          txt TEXTEQU <arg>     ;; set "txt" to content of arg num
          EXITM
        ENDIF
      ENDM
      IFNDEF txt
        txt TEXTEQU <-1>        ;; return -1 if num out of range
      ENDIF
      EXITM txt
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; -------------
  ; expand prefix
  ; -------------
    expand_prefix MACRO txtitm
      LOCAL prefix1,wrd,nu,varname

      prefix1 SUBSTR <txtitm>,1,1

   ;; usable characters are "&" "*" "@" "#" "?" "^" "~" "`" "/"

        IFIDN prefix1,<&>                   ;; reference operator
          nu SUBSTR <txtitm>,2
          wrd CATSTR <ADDR >,nu
          EXITM <wrd>
        ENDIF

        IFIDN prefix1,<*>                   ;; indirection operator
          nu SUBSTR <txtitm>,2
          .data?
            varname dd ?
          .code
          push ebx
          mov ebx, nu
          mov ebx, [ebx]                    ;; dereference variable in EBX
          mov varname, ebx
          pop ebx
          EXITM <varname>
        ENDIF

      EXITM <txtitm>                        ;; exit with original argument
    ENDM

  ; ----------------------------------------------------------------
  ; invoke enhancement. Add quoted text support to any procedure
  ; or API call by using this macro instead of the standard invoke.
  ; LIMITATION : quoted text must be plain text only, no ascii 
  ; values or macro reserved characters IE <>!() etc ..
  ; use chr$() or cfm$() for requirements of this type.
  ; ----------------------------------------------------------------
    fn MACRO FuncName:REQ,args:VARARG
      p@arg equ <invoke FuncName>           ;; construct invoke and function name
      FOR var,<args>                        ;; loop through all arguments
        p@arg CATSTR p@arg,<,expand_prefix(reparg(var))>   ;; replace quotes and append p@arg
      ENDM
      p@arg                                 ;; write the invoke macro
    ENDM

  ; ------------------------------------------------
  ; Function return value version of the above macro
  ; ------------------------------------------------
    rv MACRO FuncName:REQ,args:VARARG
      the@arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                        ;; loop through all arguments
        the@arg CATSTR the@arg,<,expand_prefix(reparg(var))>   ;; replace quotes and append the@arg
      ENDM
      the@arg                               ;; write the invoke macro
      EXITM <eax>                           ;; EAX as the return value
    ENDM

  ; ---------------------------------------------------
  ; The two following versions support C style escapes.
  ; ---------------------------------------------------
    fnc MACRO FuncName:REQ,args:VARARG
      the@arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                        ;; loop through all arguments
        the@arg CATSTR the@arg,<,expand_prefix(cfm$(var))> ;; replace quotes and append the@arg
      ENDM
      the@arg                               ;; write the invoke macro
    ENDM

    rvc MACRO FuncName:REQ,args:VARARG
      the@arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                        ;; loop through all arguments
        the@arg CATSTR the@arg,<,expand_prefix(cfm$(var))> ;; replace quotes and append the@arg
      ENDM
      the@arg                               ;; write the invoke macro
      EXITM <eax>                           ;; EAX as the return value
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    ; -----------------------------------------
    ; MSVCRT ASCII & UNICODE integer conversion
    ; -----------------------------------------
      ustr$ MACRO number
        LOCAL buffer
        .data?
          buffer TCHAR 40 dup (?)
          align 4
        .code
        IFNDEF __UNICODE__
          invoke crt__itoa,number,ADDR buffer,10
        ELSE
          invoke crt__itow,number,ADDR buffer,10
        ENDIF
        EXITM <eax>
      ENDM

      sstr$ MACRO number
        LOCAL buffer
        .data?
          buffer TCHAR 40 dup (?)
          align 4
        .code
        IFNDEF __UNICODE__
          invoke crt__ltoa,number,ADDR buffer,10
        ELSE
          invoke crt__ltow,number,ADDR buffer,10
        ENDIF
        EXITM <eax>
      ENDM

      uval MACRO lpstring
        IFNDEF __UNICODE__
          invoke crt_atoi,reparg(lpstring)
        ELSE
          invoke crt__wtoi,reparg(lpstring)
        ENDIF
        EXITM <eax>
      ENDM

      val equ <uval>

      sval MACRO lpstring
        IFNDEF __UNICODE__
          invoke crt_atol,reparg(lpstring)
        ELSE
          invoke crt__wtol,reparg(lpstring)
        ENDIF
        EXITM <eax>
      ENDM
    ; ---------------------------------

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    A2WDAT MACRO quoted@@text,dataname:VARARG

 ;; ------------------------------------------------------

 ;;     ASCII literal string to UNICODE "dw" conversion.
 ;;     The macro has the ASCII character range 0 - 255
 ;;     and will convert 1 byte characters in the quoted
 ;;     string to 2 byte UNICODE characters written as "dw"
 ;;     in the initialised data section.
 ;;     The final string length is dictated by the MASM line
 ;;     length limit and is set at 240 characters.
 ;; 
 ;;     This MACRO is primarily designed to be called by
 ;;     other macros, it does not create a .DATA section
 ;;     and it does not terminate the string data it writes.
 ;; 
 ;;     This characteristic is so the macro can be called
 ;;     repeatedly by another macro. The calling macro
 ;;     then terminates the string when it has no more
 ;;     to write.
 ;; 
 ;;     The optional dataname label is designed to be used
 ;;     on the first call and ommitted on subsequent calls
 ;;     when adding text to the original label address.
 ;; 
 ;;     You can write a .DATA section entry in this manner.
 ;; 
 ;;     .data
 ;;       A2WDAT "First block of text", mytext
 ;;       A2WDAT "Second block of text"
 ;;       A2WDAT "Third block of text"
 ;;       A2WDAT "Fourth block of text"
 ;;       dw 0
 ;;     .code
 ;; 
 ;;     mov eax, OFFSET mytext

 ;; ------------------------------------------------------

      LOCAL s_l_e_n
      LOCAL c_n_t_r
      ;; LOCAL item
      LOCAL add@str1
      LOCAL isquot
      LOCAL argz

      LOCAL lcnt
      LOCAL char
      LOCAL cntr

      LOCAL new@str1

      LOCAL slice@1
      LOCAL slice@2
      LOCAL slice@3
      LOCAL slice@4
      LOCAL slice@5
      LOCAL slice@6

      add@str1 equ <>

      new@str1 equ <>

      slice@1 equ <>
      slice@2 equ <>
      slice@3 equ <>
      slice@4 equ <>
      slice@5 equ <>
      slice@6 equ <>

      s_l_e_n SIZESTR <quoted@@text>
 ;;       item TEXTEQU %(s_l_e_n)
 ;;       % echo string length = item characters

      if s_l_e_n gt 240
        echo ------------------------------------------
        echo *** STRING EXCEEDS 240 character limit ***
        echo ------------------------------------------
      .ERR
      EXITM
      endif

      isquot SUBSTR <quoted@@text>,1,1
      IFDIF isquot,<">
        echo -----------------------------
        echo *** MISSING LEADING QUOTE ***
        echo -----------------------------
      .ERR
      EXITM
      ENDIF

      isquot SUBSTR <quoted@@text>,s_l_e_n,1
      IFDIF isquot,<">
        echo ------------------------------
        echo *** MISSING TRAILING QUOTE ***
        echo ------------------------------
      .ERR
      EXITM
      ENDIF

    ;; ============================================

      lcnt SIZESTR <quoted@@text>
      lcnt = lcnt - 2
      cntr = 2

      c_n_t_r = 0

      :lpstart

        argz SUBSTR <quoted@@text>,cntr,1

          if c_n_t_r lt 1
            slice@1 CATSTR slice@1,<">,argz,<">
            goto nxt
          elseif c_n_t_r lt 40
            slice@1 CATSTR slice@1,<,">,argz,<">
            goto nxt

          elseif c_n_t_r lt 41
            slice@2 CATSTR slice@2,<">,argz,<">
            goto nxt
          elseif c_n_t_r lt 80
            slice@2 CATSTR slice@2,<,">,argz,<">
            goto nxt

          elseif c_n_t_r lt 81
            slice@3 CATSTR slice@3,<">,argz,<">
            goto nxt
          elseif c_n_t_r lt 120
            slice@3 CATSTR slice@3,<,">,argz,<">
            goto nxt

          elseif c_n_t_r lt 121
            slice@4 CATSTR slice@4,<">,argz,<">
            goto nxt
          elseif c_n_t_r lt 160
            slice@4 CATSTR slice@4,<,">,argz,<">
            goto nxt

          elseif c_n_t_r lt 161
            slice@5 CATSTR slice@5,<">,argz,<">
            goto nxt
         elseif c_n_t_r lt 200
            slice@5 CATSTR slice@5,<,">,argz,<">
            goto nxt

          elseif c_n_t_r lt 201
            slice@6 CATSTR slice@6,<">,argz,<">
            goto nxt
          elseif c_n_t_r lt 240
            slice@6 CATSTR slice@6,<,">,argz,<">
            goto nxt
          endif

      :nxt
        c_n_t_r = c_n_t_r + 1

        cntr = cntr + 1
        lcnt = lcnt - 1
        if lcnt ne 0
          goto lpstart
        endif

    ;; ============================================

    ;; ---------------------------------------------------------
    ;; add a label if one is supplied else add a normal DW entry
    ;; ---------------------------------------------------------
    IFDIF <dataname>,<>
      % s_l_e_n SIZESTR <slice@1>
      if s_l_e_n ne 0
        slice@1 CATSTR <dataname dw >,slice@1
        slice@1
      endif
    ELSE
      % s_l_e_n SIZESTR <slice@1>
      if s_l_e_n ne 0
        slice@1 CATSTR <dw >,slice@1
        slice@1
      endif
    ENDIF
    ;; ---------------------------------------------------------

      % s_l_e_n SIZESTR <slice@2>
      if s_l_e_n ne 0
        slice@2 CATSTR <dw >,slice@2
        slice@2
      endif

      % s_l_e_n SIZESTR <slice@3>
      if s_l_e_n ne 0
        slice@3 CATSTR <dw >,slice@3
        slice@3
      endif

      % s_l_e_n SIZESTR <slice@4>
      if s_l_e_n ne 0
        slice@4 CATSTR <dw >,slice@4
        slice@4
      endif

      % s_l_e_n SIZESTR <slice@5>
      if s_l_e_n ne 0
        slice@5 CATSTR <dw >,slice@5
        slice@5
      endif

      % s_l_e_n SIZESTR <slice@6>
      if s_l_e_n ne 0
        slice@6 CATSTR <dw >,slice@6
        slice@6
      endif

    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    WSTR MACRO lblname,arglist:VARARG

      LOCAL qflg                    ;; quote flag
      LOCAL isqt                    ;; 1st character
      LOCAL arg                     ;; FOR loop argument

      qflg = 0                      ;; clear quote flag
      .data                         ;; write data to the DATA section

      for arg, <arglist>
        isqt SUBSTR <arg>,1,1       ;; get 1st character
          IFIDN isqt,<">            ;; test if its a quote
            IF qflg eq 0            ;; if 1st arg, add label
              A2WDAT arg,lblname    ;; write data section first entry
            ENDIF
            IF qflg eq 1            ;; else just write data
              A2WDAT arg            ;; write subsequent entry
            ENDIF
          ENDIF

          IFDIF isqt,<">            ;; if not quoted
            IF qflg eq 0            ;; if 1st arg, add label
              lblname dw arg        ;; write data section first entry as DW number
            ENDIF
            IF qflg eq 1            ;; if 1st arg, add label
              dw arg                ;; write subsequent entry as DW number
            ENDIF
          ENDIF
        qflg = 1                    ;; set flag for non 1st char
      ENDM

      dw 0                          ;; terminate data entry
      align 4                       ;; 4 byte align after terminator
    .code                           ;; change back to CODE section

    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    uni$ MACRO arglist:VARARG
      LOCAL DATA@NAME
      WSTR DATA@NAME,arglist
      EXITM <OFFSET DATA@NAME>
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    ; --------------------------------
    ; initialised GLOBAL string value
    ; --------------------------------

    ; -------------------------------------------------------
    ; The dataname passed to STRING is addressed as an OFFSET
    ; mov eax, OFFSET data_label
    ; -------------------------------------------------------
      STRING MACRO data_label,quoted_text:VARARG
        IFNDEF __UNICODE__
          .data
            data_label db quoted_text,0
            align 4
          .code
        ELSE
          WSTR data_label,quoted_text,0
        ENDIF
      ENDM

    ; -------------------------------------------------------------------
    ; The dataname passed to STRADD is addressed as a POINTER to the data
    ; mov eax, data_label
    ; -------------------------------------------------------------------
      STRADD MACRO data_label,args:VARARG
        LOCAL dataname
        IFNDEF __UNICODE__
          .data
            dataname db args
            align 4
            data_label dd dataname
          .code
        ELSE
          WSTR dataname,args
          .data
          align 4
          data_label dd dataname
          .code
        ENDIF
      ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; ********************************************************
  ; format a C style string complete with escape characters
  ; and return the offset of the result to the calling macro
  ;
  ; 3 versions are presented here,
  ; 1. acfm$ = ASCII only version
  ; 2. ucfm$ = UNICODE only version
  ; 3. cfm$  = Either ASCII or UNICODE depending on the
  ;    __UNICODE__ equate being present in the source file
  ;
  ; This allows you to force either ASCII, UNICODE or either
  ; depending on the presence of the __UNICODE__ equate
  ; ********************************************************

  ; ********************************************************
  ;   branchless ASCII version of cfm$ with no ELSE clauses.
  ; ********************************************************

    acfm$ MACRO txt:VARARG

      LOCAL ch1,char,nu$,tmp,flag,lbuf,rbuf,cpos,sln
      ch1 equ <>
      nu$ equ <>
      flag = 0

      ch1 SUBSTR <txt>,1,1              ;; check if 1st character is a quote
      IFDIF ch1,<">
        EXITM <txt>                     ;; exit with original "txt" if it is not
      ENDIF

      FORC char,<txt>                   ;; scan through characters in "txt"

        IFIDN <char>,<\>                ;; increment the flag if "\" escape character
          flag = flag + 1
        ENDIF

      ; -----------------------------------------------

        IF flag EQ 0                    ;; <<< if flag = 0 then normal APPEND character
          nu$ CATSTR nu$,<char>
        ENDIF

        IF flag EQ 1                    ;; <<< if flag = 1 then perform replacement
          IFIDN <char>,<n>
            nu$ CATSTR nu$,<",13,10,">  ;; \n = CRLF
            flag = 0
          ENDIF
          IFIDN <char>,<t>
            nu$ CATSTR nu$,<",9,">      ;; \t = TAB
            flag = 0
          ENDIF
          IFIDN <char>,<q>
            nu$ CATSTR nu$,<",34,">     ;; \q = quote
            flag = 0
          ENDIF
          IFIDN <char>,<0>
            nu$ CATSTR nu$,<",0,">      ;; \0 = embedded zero
            flag = 0
          ENDIF

       ;; ---------------------
       ;; masm specific escapes
       ;; ---------------------
          IFIDN <char>,<l>
            nu$ CATSTR nu$,<",60,">     ;; \l = <
            flag = 0
          ENDIF
          IFIDN <char>,<r>
            nu$ CATSTR nu$,<",62,">     ;; \r = >
            flag = 0
          ENDIF
          IFIDN <char>,<x>
            nu$ CATSTR nu$,<",33,">     ;; \x = !
            flag = 0
          ENDIF
          IFIDN <char>,<a>
            nu$ CATSTR nu$,<",40,">     ;; \a = (
            flag = 0
          ENDIF
          IFIDN <char>,<b>
            nu$ CATSTR nu$,<",41,">     ;; \b = )
            flag = 0
          ENDIF
        ENDIF

        IF flag EQ 2                    ;; <<< if flag = 2 APPEND the "\" character
          IFIDN <char>,<\>
            nu$ CATSTR nu$,<",92,">     ;; \\ = \
            flag = 0
          ENDIF
        ENDIF

      ; -----------------------------------------------

      ENDM

    ;; ---------------------------------------------
    ;; strip any embedded <"",> characters sequences
    ;; ---------------------------------------------
        nu$ CATSTR nu$,<,0,0,0>                 ;; append trailing zeros

        cpos INSTR nu$,<"",>                    ;; test for leading junk
        IF cpos EQ 1
          nu$ SUBSTR nu$,4                      ;; chomp off any leading junk
        ENDIF

        cpos INSTR nu$,<"",>

        WHILE cpos
          lbuf SUBSTR nu$,1,cpos-1              ;; read text before junk
          rbuf SUBSTR nu$,cpos+3                ;; read text after junk
          nu$ equ <>                            ;; clear nu$
          nu$ CATSTR lbuf,rbuf                  ;; concantenate the two
          cpos INSTR nu$,<"",>                  ;; reload cpos for next iteration
        ENDM

        sln SIZESTR nu$
        nu$ SUBSTR nu$,1,sln-6                  ;; trim off tail padding

        .data
          tmp db nu$,0
          align 4
        .code
        EXITM <OFFSET tmp>                      ;; return the DATA section OFFSET

    ENDM

  ; **********************************************************
  ;   branchless UNICODE version of cfm$ with no ELSE clauses.
  ; **********************************************************

    ucfm$ MACRO txt:VARARG

      LOCAL ch1,char,nu$,tmp,flag,lbuf,rbuf,cpos,sln
      ch1 equ <>
      nu$ equ <>
      flag = 0

      ch1 SUBSTR <txt>,1,1              ;; check if 1st character is a quote
      IFDIF ch1,<">
        EXITM <txt>                     ;; exit with original "txt" if it is not
      ENDIF

      FORC char,<txt>                   ;; scan through characters in "txt"

        IFIDN <char>,<\>                ;; increment the flag if "\" escape character
          flag = flag + 1
        ENDIF

      ; -----------------------------------------------

        IF flag EQ 0                    ;; <<< if flag = 0 then normal APPEND character
          nu$ CATSTR nu$,<char>
        ENDIF

        IF flag EQ 1                    ;; <<< if flag = 1 then perform replacement
          IFIDN <char>,<n>
            nu$ CATSTR nu$,<",13,10,">  ;; \n = CRLF
            flag = 0
          ENDIF
          IFIDN <char>,<t>
            nu$ CATSTR nu$,<",9,">      ;; \t = TAB
            flag = 0
          ENDIF
          IFIDN <char>,<q>
            nu$ CATSTR nu$,<",34,">     ;; \q = quote
            flag = 0
          ENDIF
          IFIDN <char>,<0>
            nu$ CATSTR nu$,<",0,">      ;; \0 = embedded zero
            flag = 0
          ENDIF

       ;; ---------------------
       ;; masm specific escapes
       ;; ---------------------
          IFIDN <char>,<l>
            nu$ CATSTR nu$,<",60,">     ;; \l = <
            flag = 0
          ENDIF
          IFIDN <char>,<r>
            nu$ CATSTR nu$,<",62,">     ;; \r = >
            flag = 0
          ENDIF
          IFIDN <char>,<x>
            nu$ CATSTR nu$,<",33,">     ;; \x = !
            flag = 0
          ENDIF
          IFIDN <char>,<a>
            nu$ CATSTR nu$,<",40,">     ;; \a = (
            flag = 0
          ENDIF
          IFIDN <char>,<b>
            nu$ CATSTR nu$,<",41,">     ;; \b = )
            flag = 0
          ENDIF
        ENDIF

        IF flag EQ 2                    ;; <<< if flag = 2 APPEND the "\" character
          IFIDN <char>,<\>
            nu$ CATSTR nu$,<",92,">     ;; \\ = \
            flag = 0
          ENDIF
        ENDIF

      ; -----------------------------------------------

      ENDM

    ;; ---------------------------------------------
    ;; strip any embedded <"",> characters sequences
    ;; ---------------------------------------------
        nu$ CATSTR nu$,<,0,0,0>                 ;; append trailing zeros

        cpos INSTR nu$,<"",>                    ;; test for leading junk
        IF cpos EQ 1
          nu$ SUBSTR nu$,4                      ;; chomp off any leading junk
        ENDIF

        cpos INSTR nu$,<"",>

        WHILE cpos
          lbuf SUBSTR nu$,1,cpos-1              ;; read text before junk
          rbuf SUBSTR nu$,cpos+3                ;; read text after junk
          nu$ equ <>                            ;; clear nu$
          nu$ CATSTR lbuf,rbuf                  ;; concantenate the two
          cpos INSTR nu$,<"",>                  ;; reload cpos for next iteration
        ENDM

        sln SIZESTR nu$
        nu$ SUBSTR nu$,1,sln-6                  ;; trim off tail padding

        % WSTR tmp,nu$
        EXITM <OFFSET tmp>                      ;; return the DATA section OFFSET

    ENDM

  ; ****************************************************
  ; ****************************************************

    cfm$ MACRO txt:VARARG
      IFDEF __UNICODE__
        EXITM <ucfm$(txt)>                      ;; UNICODE only version
      ENDIF
      EXITM <acfm$(txt)>                        ;; ASCII only version
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; --------------------------------------------------------------
  ; This macro is written to behave as closely as possible to the
  ; C runtime function "printf". The lack of return value is
  ; to allow the closest method to writing C code. It supports
  ; both ASCII and UNICODE and uses the C runtime function
  ; "wprintf" to provide the UNICODE support.
  ;
  ; printf("%d\t%d\t%Xh\n", 123, 456, 1024);
  ;
  ; The return value is available in the EAX register if required.
  ; The original ASCII version was written by Michael Webster.
  ; --------------------------------------------------------------

    printf MACRO format:REQ, args:VARARG
      IFNDEF __UNICODE__
        IFNB <args>
          fn crt_printf, cfm$(format), args
        ELSE
          fn crt_printf, cfm$(format)
        ENDIF
        EXITM <>
      ELSE
        IFNB <args>
          fn crt_wprintf, cfm$(format), args
        ELSE
          fn crt_wprintf, cfm$(format)
        ENDIF
        EXITM <>
      ENDIF
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

comment * -------------------------------------------------------
        Each of the following macros has its own dedicated 260
        CHARACTER buffer. The OFFSET returned by each macro can be
        used directly in code but if the macro is called again
        the data in the dedicated buffer will be overwritten
        with the new result.

        mov str1, ptr$(buffer)
        mov str2, pth$()

        invoke szCopy str2,str1 ; ASCII
        invoke ucCopy str2,str1 ; UNICODE

          or the macro

        cst str2, str1          ; __UNICODE__ aware

        Empty brackets should be used with these macros as they
        take no parameters. pth$() CurDir$() etc ...
        ------------------------------------------------------- *

      pth$ MACRO            ;; application path OFFSET returned
        IFNDEF pth__equate__flag
        .data?
            pth__260_CHAR__buffer TCHAR MAX_PATH dup (?)
        .code
        pth__equate__flag equ <1>
        ENDIF
        IFNDEF __UNICODE__
          invoke GetAppPath,ADDR pth__260_CHAR__buffer
        ELSE
          invoke GetAppPathW
        ENDIF
        EXITM <eax>
      ENDM

      CurDir$ MACRO
        IFNDEF cdir__equate__flag
        .data?
            cdir__260_CHAR__buffer TCHAR MAX_PATH dup (?)
        .code
        cdir__equate__flag equ <1>
        ENDIF
        invoke GetCurrentDirectory,MAX_PATH,ADDR cdir__260_CHAR__buffer
        mov eax, OFFSET cdir__260_CHAR__buffer
        EXITM <eax>
      ENDM

      SysDir$ MACRO
        IFNDEF sys__equate__flag
        .data?
            sysdir__260_CHAR__buffer TCHAR MAX_PATH dup (?)
        .code
        sys__equate__flag equ <1>
        ENDIF
        invoke GetSystemDirectory,ADDR sysdir__260_CHAR__buffer,MAX_PATH
        mov eax, OFFSET sysdir__260_CHAR__buffer
        EXITM <eax>
      ENDM

      WinDir$ MACRO
        IFNDEF wdir__equate__flag
        .data?
            windir__260_CHAR__buffer TCHAR MAX_PATH dup (?)
        .code
        wdir__equate__flag equ <1>
        ENDIF
        invoke GetWindowsDirectory,ADDR windir__260_CHAR__buffer,MAX_PATH
        mov eax, OFFSET windir__260_CHAR__buffer
        EXITM <eax>
      ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; ******************************************
  ; DOS style directory manipulation macros  *
  ; The parameters passed to these directory *
  ; macros should be zero terminated string  *
  ; addresses.                               *
  ; ******************************************
      chdir MACRO pathname
        invoke SetCurrentDirectory,reparg(pathname)
      ENDM
      CHDIR equ <chdir>

      mkdir MACRO dirname
        invoke CreateDirectory,reparg(dirname),NULL
      ENDM
      MKDIR equ <mkdir>

      rndir MACRO oldname,newname
        invoke MoveFile,reparg(oldname),reparg(newname)
      ENDM
      RNDIR equ <rndir>

      rmdir MACRO dirname
        invoke RemoveDirectory,reparg(dirname)
      ENDM
      RMDIR equ <rmdir>

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    ascii MACRO quoted_text:VARARG
      LOCAL txtname
      .data
        txtname db quoted_text,0
      .code
      EXITM <OFFSET txtname>
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    ; ******************************************************
    ; BASIC style conversions from string to 32 bit integer
    ; ******************************************************

      hval MACRO lpstring       ; hex string to unsigned 32 bit integer
        invoke htodw, reparg(lpstring)
        EXITM <eax>
      ENDM

    ; ********************************
    ; BASIC string function emulation
    ; ********************************
      add$ MACRO lpSource,lpAppend
        IFNDEF __UNICODE__
          invoke szCatStr,tstarg(lpSource),reparg(lpAppend)
          EXITM <eax>
        ELSE
          push esi
          mov esi, tstarg(lpSource)
          invoke ucCatStr,tstarg(lpSource),reparg(lpAppend)
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      append$ MACRO string,buffer,location
        IFNDEF __UNICODE__
          invoke szappend,string,reparg(buffer),location
        ELSE
          invoke ucappend,string,reparg(buffer),location
        ENDIF
        EXITM <eax>
      ENDM

  ; -----------------------------------------
  ; non branching version with no ELSE clause
  ; -----------------------------------------
      chr$ MACRO any_text:VARARG
        LOCAL txtname
        .data
          IFDEF __UNICODE__
            WSTR txtname,any_text
            align 4
            .code
            EXITM <OFFSET txtname>
          ENDIF

          txtname db any_text,0
          align 4
          .code
          EXITM <OFFSET txtname>
      ENDM

      cmp$ MACRO arg1,arg2
        invoke lstrcmp,reparg(arg1),reparg(arg2)
        EXITM <eax>
      ENDM

      cmpi$ MACRO arg1,arg2
        invoke lstrcmpi,reparg(arg1),reparg(arg2)
        EXITM <eax>
      ENDM

      ptr$ MACRO buffer
        lea eax, buffer
        mov WORD PTR [eax], 0
        EXITM <eax>
      ENDM

      len MACRO lpString
        IFNDEF __UNICODE__
          invoke szLen,reparg(lpString)
        ELSE
          invoke ucLen,reparg(lpString)
        ENDIF
        EXITM <eax>
      ENDM

      find$ MACRO spos,lpMainString,lpSubString
        IFNDEF __UNICODE__
          invoke InString,spos,reparg(lpMainString),reparg(lpSubString)
          EXITM <eax>
        ELSE
          invoke ucFind,spos,reparg(lpMainString),reparg(lpSubString)
          EXITM <eax>
        ENDIF
      ENDM

      istring equ <find$>

      ucase$ MACRO lpString
        IFNDEF __UNICODE__
          invoke szUpper,reparg(lpString)
          EXITM <eax>
        ELSE
          push esi
          mov esi, reparg(lpString)
          fn CharUpperBuff,esi,rv(ucLen,esi)
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      lcase$ MACRO lpString
        IFNDEF __UNICODE__
          invoke szLower,reparg(lpString)
        EXITM <eax>
        ELSE
          push esi
          mov esi, reparg(lpString)
          fn CharLowerBuff,esi,rv(ucLen,esi)
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      left$ MACRO lpString,slen
        IFNDEF __UNICODE__
          invoke szLeft,reparg(lpString),reparg(lpString),slen
        ELSE
          push esi
          mov esi, reparg(lpString)
          invoke ucLeft,esi,esi,slen
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
        EXITM <eax>
      ENDM

      right$ MACRO lpString,slen
        IFNDEF __UNICODE__
          invoke szRight,reparg(lpString),reparg(lpString),slen
          EXITM <eax>
        ELSE
          push esi
          mov esi, reparg(lpString)
          invoke ucRight,esi,esi,slen
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      rev$ MACRO lpString
        IFNDEF __UNICODE__
          invoke szRev,reparg(lpString),reparg(lpString)
          EXITM <eax>
        ELSE
          push esi
          mov esi, reparg(lpString)
          invoke ucRev,esi,esi
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      ltrim$ MACRO lpString
        IFNDEF __UNICODE__
          invoke szLtrim,reparg(lpString),reparg(lpString)
          mov eax, ecx
          EXITM <eax>
        ELSE
          push esi
          mov esi, reparg(lpString)
          invoke ucLtrim,esi,esi
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      rtrim$ MACRO lpString
        IFNDEF __UNICODE__
          invoke szRtrim,reparg(lpString),reparg(lpString)
          mov eax, ecx
          EXITM <eax>
        ELSE
          push esi
          mov esi, reparg(lpString)
          invoke ucRtrim,esi,esi
          mov eax, esi
          pop esi
          EXITM <eax>
        ENDIF
      ENDM

      trim$ MACRO lpString
        IFNDEF __UNICODE__
          invoke szTrim,reparg(lpString)
          mov eax, ecx
          EXITM <eax>
        ELSE
          EXITM <ltrim$(rtrim$(lpString))>
        ENDIF
      ENDM

      remove$ MACRO src,substr
        IFDEF __UNICODE__
          invoke ucRemove,reparg(src),reparg(src),reparg(substr)
          EXITM <eax>
        ENDIF
        invoke szRemove,reparg(src),reparg(src),reparg(substr)
        EXITM <eax>
      ENDM

      uhex$ MACRO DDvalue   ;; unsigned DWORD to hex string
        LOCAL rvstring
        .data
          rvstring db 12 dup (0)
        align 4
        .code
        invoke dw2hex,DDvalue,ADDR rvstring
        EXITM <OFFSET rvstring>
      ENDM

    ; ----------------------------------
    ; API string functions from KERNEL32
    ; ----------------------------------
      lstrcat$ MACRO arg1,arg2
        invoke lstrcat,tstarg(arg1),reparg(arg2)
        EXITM <eax>
      ENDM

      lstrcmp$ MACRO arg1,arg2
        invoke lstrcmp,reparg(arg1),reparg(arg2)
        EXITM <eax>
      ENDM

      lstrcmpi$ MACRO arg1,arg2
        invoke lstrcmpi,reparg(arg1),reparg(arg2)
        EXITM <eax>
      ENDM

      lstrcpy$ MACRO arg1,arg2
        invoke lstrcpy,tstarg(arg1),reparg(arg2)
        EXITM <eax>
      ENDM

      lstrcpyn$ MACRO arg1,arg2,ccnt
        invoke lstrcpyn,tstarg(arg1),reparg(arg2),ccnt
        EXITM <eax>
      ENDM
    ; ----------------------------------

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; ------------------------------------------------------
  ; macro for concantenating strings using the szMultiCat
  ; procedure written by Alexander Yackubtchik.
  ;
  ; USAGE strcat buffer,str1,str2,str3 etc ...
  ; 
  ; buffer must be large enough to contain all of the
  ; strings to append. Limit is set by maximum line
  ; length in MASM.
  ; ------------------------------------------------------
    strcat MACRO arguments:VARARG
    LOCAL txt
    LOCAL pcount
      IFNDEF __UNICODE__
        txt equ <invoke szMultiCat,>        ;; ANSI lead string
      ELSE
        txt equ <invoke ucMultiCat,>        ;; UNICODE lead string
      ENDIF
        pcount = 0
          FOR arg, <arguments>
            pcount = pcount + 1             ;; count arguments
          ENDM
        % pcount = pcount - 1               ;; dec 1 for 1st arg
        txt CATSTR txt,%pcount              ;; append number to lead string
          FOR arg, <arguments>
            txt CATSTR txt,<,>,reparg(arg)
          ENDM
        txt                                 ;; put result in code
    ENDM

  ; ----------------------------------------------
  ; this version is used in the function position
  ; ----------------------------------------------
    cat$ MACRO arguments:VARARG
      LOCAL txt
      LOCAL spare
      LOCAL pcount
        spare equ <>
          FOR arg, <arguments>
            spare CATSTR spare,tstarg(arg)  ;; test if 1st arg is quoted text
            EXITM                           ;; and produce error if it is
          ENDM
        IFNDEF __UNICODE__
          txt equ <invoke szMultiCat,>      ;; ANSI lead string
        ELSE
          txt equ <invoke ucMultiCat,>      ;; UNICODE lead string
        ENDIF
        pcount = 0
          FOR arg, <arguments>
            pcount = pcount + 1             ;; count arguments
          ENDM
        % pcount = pcount - 1               ;; dec 1 for 1st arg
        txt CATSTR txt,%pcount              ;; append number to lead string
          FOR arg, <arguments>
            txt CATSTR txt,<,>,reparg(arg)
          ENDM
        txt                                 ;; put result in code
      EXITM <eax>
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; -------------------------------------------------
  ; UNICODE aware API based environment string macros
  ; -------------------------------------------------
    envget$ MACRO str1
      IFNDEF get@@env@@buffer
        .data?
          buffer@@1024 TCHAR 1024 dup (?)
        .code
        get@@env@@buffer equ 1
      ENDIF
      mov DWORD PTR buffer@@1024[0], 0  ;; clear buffer each call
      fn GetEnvironmentVariable,reparg(str1),OFFSET buffer@@1024,1024
      EXITM <OFFSET buffer@@1024>
    ENDM

    envset$ MACRO evar,evalue
      IFIDN <evalue>,<0>
        fn SetEnvironmentVariable,reparg(evar),NULL
      ELSE
        fn SetEnvironmentVariable,reparg(evar),reparg(evalue)
      ENDIF
      EXITM <eax>
    ENDM

  ; ---------------------------------------
  ; Legacy MSVCRT environment string macros
  ; ---------------------------------------
    env$ MACRO item
      invoke crt_getenv,reparg(item)
      EXITM <eax>
    ENDM

    setenv MACRO value
      invoke crt__putenv,reparg(value)
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

    ; -------------------------------------------
    ;             Pseudo mnemonics.
    ; These macros emulate assembler mnemonics
    ; but perform higher level operations not
    ; directly supported by the instruction set
    ; NOTE: The parameter order is the normal
    ; assembler order of,
    ; instruction/destination/source
    ; -------------------------------------------

    ; --------------------------
    ; szstring to szstring copy
    ; --------------------------
      cst MACRO arg1,arg2
        IFNDEF __UNICODE__
          invoke szCopy,reparg(arg2),tstarg(arg1)
        ELSE
          invoke ucCopy,reparg(arg2),tstarg(arg1)
        ENDIF
      ENDM

    ; ----------------------------
    ; memory to memory assignment
    ; ----------------------------
      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

    ; --------------------------------------------------
    ; memory to memory assignment using the EAX register
    ; --------------------------------------------------
      mrm MACRO m1, m2
        mov eax, m2
        mov m1, eax
      ENDM

    ; *******************************************
    ;             String Assign                 *
    ; Assign quoted text to a locally declared  *
    ; string handle (DWORD variable) in a proc  *
    ; to effectively have a LOCAL scope strings *
    ; EXAMPLE :                                 *
    ; sas MyVar,"This is an assigned string"    *
    ; *******************************************
      sas MACRO var,quoted_text:VARARG
        LOCAL txtname
        IFNDEF __UNICODE__
        .data
          txtname db quoted_text,0
          align 4
        .code
        ELSE
          WSTR txtname,quoted_text
        ENDIF
        mov var, OFFSET txtname
      ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; -------------------------
  ; determine an operand type
  ; -------------------------
    op_type MACRO arg:REQ
      LOCAL result
      result = opattr(arg)
        IF result eq 37         ;; label, either local or global
          EXITM %1
        ELSEIF result eq 42     ;; GLOBAL var
          EXITM %2
        ELSEIF result eq 98     ;; LOCAL  var
          EXITM %3
        ELSEIF result eq 36     ;; immediate operand or constant
          EXITM %4
        ELSEIF result eq 48     ;; register
          EXITM %5
        ELSEIF result eq 805    ;; local procedure in code
          EXITM %6
        ELSEIF result eq 933    ;; external procedure or API call
          EXITM %7
        ENDIF
      EXITM %0                  ;; anything else
    ENDM

    ; *************************************
    ; Return a register size in BYTES or  *
    ; 0 if the argument is not a register *
    ; *************************************
    regsize MACRO item
      LOCAL rval,ln
      rval = 0
      ln SIZESTR <item>
    
      IF ln EQ 2
        goto two
      ELSEIF ln EQ 3
        goto three
      ELSEIF ln EQ 4
        goto four
      ELSEIF ln EQ 5
        goto five
      ELSEIF ln EQ 6
        goto six
      ELSEIF ln EQ 8
        goto eight
      ELSE
        goto notreg
      ENDIF
    
    :two
      for arg,<al,ah,bl,bh,cl,ch,dl,dh>
        IFIDNI <arg>,<item>
          rval = 1
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
    
      for arg,<ax,bx,cx,dx,sp,bp,si,di>
        IFIDNI <arg>,<item>
          rval = 2
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
      goto notreg
    
    :three
      for arg,<eax,ebx,ecx,edx,esp,ebp,esi,edi>
        IFIDNI <arg>,<item>
          rval = 4
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
    
      for arg,<st0,st1,st2,st3,st4,st5,st6,st7>
        IFIDNI <arg>,<item>
          rval = 10
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
    
      for arg,<mm0,mm1,mm2,mm3,mm4,mm5,mm6,mm7>
        IFIDNI <arg>,<item>
          rval = 8
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
      goto notreg
    
    :four
      for arg,<xmm0,xmm1,xmm2,xmm3,xmm4,xmm5,xmm6,xmm7>
        IFIDNI <arg>,<item>
          rval = 16
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
      goto notreg
    
    :five
      for arg,<mm(0),mm(1),mm(2),mm(3),mm(4),mm(5),mm(6),mm(7)>
        IFIDNI <arg>,<item>
          rval = 8
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
    
      for arg,<st(0),st(1),st(2),st(3),st(4),st(5),st(6),st(7)>
        IFIDNI <arg>,<item>
          rval = 10
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
      goto notreg
    
    :six
      for arg,<xmm(0),xmm(1),xmm(2),xmm(3),xmm(4),xmm(5),xmm(6),xmm(7)>
        IFIDNI <arg>,<item>
          rval = 16
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF
      
    :eight
      for arg,<edx::eax,ecx::ebx>
        IFIDNI <arg>,<item>
          rval = 8
          EXITM
        ENDIF
      ENDM
      IF rval NE 0
        EXITM %rval
      ENDIF  
    
    :notreg
      EXITM %rval
    ENDM

;---------------------------------------------------

    issize MACRO var:req, bytes:req
        LOCAL rval
        rval = regsize(var) 
        IFE rval ; if not a register use SIZE 
            IF SIZE var EQ bytes
                EXITM <1>
            ELSE
                EXITM <0>
            ENDIF
        ELSE   ; it's a register       
            IF rval EQ bytes
                EXITM <1>        
            ELSE
                EXITM <0>
            ENDIF    
        ENDIF
    ENDM

; ----------------------------------------------

    isregister MACRO var:req
        IF regsize(var)
            EXITM <1>
        ELSE
            EXITM <0>
        ENDIF    
    ENDM    

  ; -----------------------------------------------------
  ; "catargs" takes 3 arguments.
  ; 1.  the NAME of the calling macro for error reporting
  ; 2.  the ADDRESS of the memory allocated for the text
  ; 3.  the ARGUMENTLIST of strings passed to the caller
  ; -----------------------------------------------------
    catargs MACRO mname,mem,args:VARARG
      LOCAL lcnt,var                        ;; LOCAL loop counter

      lcnt = argcount(args)                 ;; get the VARARG argument count
      REPEAT lcnt

      var equ repargof(getarg(lcnt,args))
      ;; -------------------------------------------------
      ;; if argument is a register, display error and stop
      ;; -------------------------------------------------
        IF op_type(repargof(getarg(lcnt,args))) EQ 4
          echo -------------------------------------------
        % echo Argument num2str(lcnt) INVALID OPERAND in mname
          echo ERROR Register or register return
          echo value not allowed in this context
          echo Valid options must be memory operands.
          echo They can occur in the following forms,
          echo *        1. quoted text
          echo *        2. zero terminated string address
          echo *        3. macro that returns an OFFSET
          echo *        4. built in character operators
          echo -------------------------------------------
        .err
        ENDIF
        IFIDN var,<lb>                      ;; ( notation
          IFNDEF @left_bracket@
            .data
              @left_bracket@ db "(",0
            .code
          ENDIF
          push OFFSET @left_bracket@
          goto overit
        ENDIF
        IFIDN var,<rb>                      ;; ) notation
          IFNDEF @right_bracket@
            .data
              @right_bracket@ db ")",0
            .code
          ENDIF
          push OFFSET @right_bracket@
          goto overit
        ENDIF
        IFIDN var,<la>                      ;; < notation
          IFNDEF @left_angle@
            .data
              @left_angle@ db "<",0
            .code
          ENDIF
          push OFFSET @left_angle@
          goto overit
        ENDIF
        IFIDN var,<ra>                      ;; > notation
          IFNDEF @right_angle@
            .data
              @right_angle@ db ">",0
            .code
          ENDIF
          push OFFSET @right_angle@
          goto overit
        ENDIF
        IFIDN var,<q>                       ;; quote notation
          IFNDEF @quote@
            .data
              @quote@ db 34,0
            .code
          ENDIF
          push OFFSET @quote@
          goto overit
        ENDIF
        IFIDN var,<n>                       ;; newline notation
          IFNDEF @nln@
            .data
              @nln@ db 13,10,0
            .code
          ENDIF
          push OFFSET @nln@
          goto overit
        ENDIF
        IFIDN var,<t>                       ;; tab notation
          IFNDEF @tab@
            .data
              @tab@ db 9,0
            .code
          endif
          push offset @tab@
          goto overit
        ENDIF
        push var                            ;; push current argument
      :overit
        lcnt = lcnt - 1
      ENDM

      push mem                              ;; push the buffer address
      push argcount(args)                   ;; push the argument count
      call szMultiCat                       ;; call the C calling procedure
      add esp, argcount(args)*4+8           ;; correct the stack
    ENDM

  ; ******************************************************
  ; num2str feeds a numeric macro value through a seperate
  ; macro to force a text return value. It is useful for
  ; displaying loop based debugging info and for display
  ; purposes with error reporting.
  ; NOTE :
  ; prefix the "echo" to display this result with "%"
  ; EXAMPLE :
  ; % echo num2str(arg)
  ; ******************************************************
    num2str MACRO arg
      EXITM % arg
    ENDM

  ; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

    arralloc$ MACRO member_count        ;; create a new empty array
      EXITM <rv(arralloc,member_count)>
    ENDM

    arrealloc$ MACRO arr,cnt            ;; change the size of an existing array
      EXITM <rv(arrealloc,arr,cnt)>
    ENDM

    arrfree$ MACRO arr                  ;; destroy an array freeing all of the memory it uses
      EXITM <rv(arrfree,arr)>
    ENDM

  ; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

    arrset$ MACRO arr,indx,ptxt         ;; write text data to an array member
      EXITM <rv(arrset,arr,indx,reparg(ptxt))>
    ENDM

    arrbin$ MACRO arr,indx,psrc,lsrc    ;; write binary data to an array member
      EXITM <rv(arrbin,arr,indx,psrc,lsrc>)
    ENDM

    arrtxt$ MACRO ptxt                  ;; load multiline text buffer into array
      EXITM <rv(arrtxt,ptxt)>
    ENDM

    arrfile$ MACRO file_name            ;; load multiline text file into array
      EXITM <rv(arrfile,reparg(file_name))>
    ENDM

  ; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

    arrget$ MACRO arr,indx              ;; get the address of an array member
      EXITM <rv(arrget,arr,indx)>
    ENDM

    arrcnt$ MACRO arr                   ;; get the stored member count
      EXITM <rv(arrcnt,arr)>
    ENDM

    arrlen$ MACRO arr,indx              ;; get the stored length of a single member
      EXITM <rv(arrlen,arr,indx)>
    ENDM

    arrtotal$ MACRO arr,crlf            ;; calculate entire array storage
      EXITM <rv(arrtotal,arr,crlf)>     ;; with or without trailing CRLF
    ENDM

; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

    arr2file$ MACRO arr,ptxt            ;; write array to text file with CRLF line termination
      EXITM <rv(arr2file,parr,reparg(ptxt))>    ;; returning written file length
    ENDM

    arr2mem$ MACRO arr,pmem             ;; binary write array to memory with
      EXITM <rv(arr2mem,arr,pmem)>      ;; no trailing CRLF
    ENDM

    arr2text$ MACRO arr,pmem            ;; write array to text buffer
      EXITM <rv(arr2text,arr,pmem)>
    ENDM

; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

    arrtrunc$ MACRO arr,indx            ;; truncate an existing array
      EXITM <rv(arrtrunc,arr,indx)>
    ENDM

    arrextnd$ MACRO arr,indx            ;; extend an existing array
      EXITM <rv(arrextnd,arr,indx)>
    ENDM

; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

    ; ----------------------------------------------------------------------
    ; A macro that encapsulates GetLastError() and FormatMessage() to return
    ; the system based error string for debugging API functions that return
    ; error information with the GetLastError() API call.
    ; ----------------------------------------------------------------------
      LastError$ MACRO
        IFNDEF @@_e_r_r_o_r_@@
          .data?
            @@_e_r_r_o_r_@@ db 1024 dup (?)
          .code
        ENDIF
        pushad
        pushfd
        invoke GetLastError
        mov edi,eax
        invoke FormatMessage,FORMAT_MESSAGE_FROM_SYSTEM,
                             NULL,edi,0,ADDR @@_e_r_r_o_r_@@,1024,NULL
        popfd
        popad
        EXITM <OFFSET @@_e_r_r_o_r_@@>
      ENDM

    ; --------------------------------------------
    ; the following two macros are for prototyping
    ; direct addresses with a known argument list.
    ; --------------------------------------------
      SPROTO MACRO func_addr:REQ,arglist:VARARG     ;; STDCALL version
        LOCAL lp,var
        .data?
          func_addr dd ?
        .const
        var typedef PROTO STDCALL arglist
        lp TYPEDEF PTR var
        EXITM <equ <(TYPE lp) PTR func_addr>>
      ENDM

      CPROTO MACRO func_addr:REQ,arglist:VARARG     ;; C calling version
        LOCAL lp,var
        .data?
          func_addr dd ?
        .const
        var typedef PROTO C arglist
        lp TYPEDEF PTR var
        EXITM <equ <(TYPE lp) PTR func_addr>>
      ENDM

  ; ------------------------------------------------------
  ; turn stackframe off and on for low overhead procedures
  ; ------------------------------------------------------
    stackframe MACRO arg
      IFIDN <on>,<arg>
        OPTION PROLOGUE:PrologueDef
        OPTION EPILOGUE:EpilogueDef
      ELSEIFIDN <off>,<arg>
        OPTION PROLOGUE:NONE
        OPTION EPILOGUE:NONE
      ELSE
        echo -----------------------------------
        echo ERROR IN "stackframe" MACRO
        echo Incorrect Argument Supplied
        echo Options 
        echo 1. off Turn default stack frame off
        echo 2. on  Restore stack frame defaults
        echo SYNTAX : frame on/off
        echo -----------------------------------
        .err
      ENDIF
    ENDM

comment * ------------------------------------------
    jmp_table is used for arrays of label addresses
    MASM supports writing the label name directly
    into the .DATA section.
    EXAMPLE:
    jmp_table name,lbl1,lbl2,lbl3,lbl4
        ------------------------------------------ *
    jmp_table MACRO name,args:VARARG
      .data
        align 4
        name dd args
      .code
    ENDM

    ; *******************
    ; DATA DECLARATIONS *
    ; *******************

    ; -------------------------------------
    ; initialised GLOBAL value of any type
    ; -------------------------------------
      GLOBAL MACRO variable:VARARG
      .data
      align 4
        variable
      .code
      ENDM

    ; --------------------------------
    ; initialise floating point vaues
    ; --------------------------------
      FLOAT4 MACRO name,value
        .data
        align 4
          name REAL4 value
        .code
      ENDM

      FLOAT8 MACRO name,value
        .data
        align 4
          name REAL8 value
        .code
      ENDM

      FLOAT10 MACRO name,value
        .data
        align 4
          name REAL10 value
        .code
      ENDM

    ; **********************************************************
    ; function style macros for direct insertion of data types *
    ; **********************************************************

      FP4 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL4 value
        .code
        EXITM <vname>
      ENDM

      FP8 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL8 value
        .code
        EXITM <vname>
      ENDM

      FP10 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL10 value
        .code
        EXITM <vname>
      ENDM

    ; --------------------------------------------
    ; FLD does not accept immediate operands. These
    ; macros emulate loading an immediate value by
    ; loading the value into the .DATA section.
    ; EXAMPLE : fld8 1234.56789
    ; --------------------------------------------
      fld4 MACRO fpvalue
        LOCAL name
        .data
          name REAL4 fpvalue
          align 4
        .code
        fld name
      ENDM

      fld8 MACRO fpvalue
        LOCAL name
        .data
          name REAL8 fpvalue
          align 4
        .code
        fld name
      ENDM

      fld10 MACRO fpvalue
        LOCAL name
        .data
          name REAL10 fpvalue
          align 4
        .code
        fld name
      ENDM
    ; --------------------------------------------

    ; **********************************************
    ; The original concept for the following macro *
    ; was designed by "huh" from New Zealand.      *
    ; **********************************************

    ; ---------------------
    ; literal string MACRO
    ; ---------------------
      literal MACRO quoted_text:VARARG
        LOCAL local_text
        .data
          local_text db quoted_text,0
        align 4
        .code
        EXITM <local_text>
      ENDM
    ; --------------------------------
    ; string address in INVOKE format
    ; --------------------------------
      SADD MACRO quoted_text:VARARG
        EXITM <ADDR literal(quoted_text)>
      ENDM
    ; --------------------------------
    ; string OFFSET for manual coding
    ; --------------------------------
      CTXT MACRO quoted_text:VARARG
        EXITM <offset literal(quoted_text)>
      ENDM

    ; -----------------------------------------------------
    ; string address embedded directly in the code section
    ; -----------------------------------------------------
      CADD MACRO quoted_text:VARARG
        LOCAL vname,lbl
          jmp lbl
            vname db quoted_text,0
          align 4
          lbl:
        EXITM <ADDR vname>
      ENDM

    ; --------------------------------------------------
    ; Macro for placing an assembler instruction either
    ; within another or within a procedure call
    ; --------------------------------------------------

    ASM MACRO parameter1,source
      LOCAL mnemonic
      LOCAL dest
      LOCAL poz

      % poz INSTR 1,<parameter1>,< >             ;; get the space position
      mnemonic SUBSTR <parameter1>, 1, poz-1     ;; get the mnemonic
      dest SUBSTR <parameter1>, poz+1            ;; get the first argument

      mnemonic dest, source

      EXITM <dest>
    ENDM

    ; ------------------------------------------------------------
    ; Macro for nesting function calls in other invoke statements
    ; ------------------------------------------------------------
      FUNC MACRO parameters:VARARG
        invoke parameters
        EXITM <eax>
      ENDM

    ; -----------------------------------
    ; create a font and return its handle
    ; -----------------------------------
      GetFontHandle MACRO fnam:REQ,fsiz:REQ,fwgt:REQ
        invoke RetFontHandle,reparg(fnam),fsiz,fwgt
        EXITM <eax>
      ENDM

  ; **************
  ; File IO Macros
  ; **************
  ; ---------------------------------------------------------------------
  ; create a new file with read / write access and return the file handle
  ; ---------------------------------------------------------------------
    fcreate MACRO filename
      invoke CreateFileA,reparg(filename),GENERIC_READ or GENERIC_WRITE,
                        NULL,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
      EXITM <eax>       ;; return file handle
    ENDM

    fcreateW MACRO filename
      invoke CreateFileW,reparg(filename),GENERIC_READ or GENERIC_WRITE,
                        NULL,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
      EXITM <eax>       ;; return file handle
    ENDM

  ; ------------------
  ; delete a disk file
  ; ------------------
    fdelete MACRO filename
      invoke DeleteFileA,reparg(filename)
      EXITM <eax>
    ENDM

    fdeleteW MACRO filename
      invoke DeleteFileW,reparg(filename)
      EXITM <eax>
    ENDM

  ; ------------------------------
  ; flush open file buffer to disk
  ; ------------------------------
    fflush MACRO hfile
      invoke FlushFileBuffers,hfile
    ENDM

  ; -------------------------------------------------------------------------
  ; open an existing file with read / write access and return the file handle
  ; -------------------------------------------------------------------------
    fopen MACRO filename
      invoke CreateFileA,reparg(filename),GENERIC_READ or GENERIC_WRITE,
                        NULL,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
      EXITM <eax>       ;; return file handle
    ENDM

    fopenW MACRO filename
      invoke CreateFileW,reparg(filename),GENERIC_READ or GENERIC_WRITE,
                        NULL,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
      EXITM <eax>       ;; return file handle
    ENDM


  ; ------------------
  ; close an open file
  ; ------------------
    fclose MACRO arg:REQ
      invoke CloseHandle,arg
    ENDM

  ; ------------------------------------------------
  ; read data from an open file into a memory buffer
  ; ------------------------------------------------
    fread MACRO hFile,buffer,bcnt
      LOCAL var
      .data?
        var dd ?
      .code
      invoke ReadFile,hFile,buffer,bcnt,ADDR var,NULL
      mov eax, var
      EXITM <eax>       ;; return bytes read
    ENDM

  ; ----------------------------------------
  ; write data from a buffer to an open file
  ; ----------------------------------------
    fwrite MACRO hFile,buffer,bcnt
      LOCAL var
      .data?
        var dd ?
      .code
      invoke WriteFile,hFile,buffer,bcnt,ADDR var,NULL
      mov eax, var
      EXITM <eax>       ;; return bytes written
    ENDM

  ; ----------------------------------------------------
  ; write a line of zero terminated text to an open file
  ; ----------------------------------------------------
    fprint MACRO hFile:REQ,text:VARARG  ;; zero terminated text
      LOCAL var
      LOCAL pst
      .data?
        var dd ?
        pst dd ?
      .code
      mov pst, repargv(text)
      invoke WriteFile,hFile,pst,len(pst),ADDR var,NULL
      invoke WriteFile,hFile,chr$(13,10),2,ADDR var,NULL
    ENDM

  ; ---------------------------------
  ; write zero terminated text with C
  ; style formatting to an open file.
  ; ---------------------------------
    fprintc MACRO hFile:REQ,text:VARARG  ;; zero terminated text
      LOCAL var
      LOCAL pst
      .data?
        var dd ?
        pst dd ?
      .code
      mov pst, cfm$(text)
      invoke WriteFile,hFile,pst,len(pst),ADDR var,NULL
    ENDM

  ; ------------------------------------
  ; set the position of the file pointer
  ; ------------------------------------
    fseek MACRO hFile,distance,location
      IFIDN <location>,<BEGIN>
        var equ <FILE_BEGIN>
      ELSEIFIDN <location>,<CURRENT>
        var equ <FILE_CURRENT>
      ELSEIFIDN <location>,<END>
        var equ <FILE_END>
      ELSE
        var equ <location>
      ENDIF
      invoke SetFilePointer,hFile,distance,0,var
      EXITM <eax>               ;; return current file offset
    ENDM

  ; ------------------------------------------------
  ; set end of file at current file pointer location
  ; ------------------------------------------------
    fseteof MACRO hFile
      invoke SetEndOfFile,hFile
    ENDM

  ; -------------------------------
  ; return the size of an open file
  ; -------------------------------
    fsize MACRO hFile
      invoke GetFileSize,hFile,NULL
      EXITM <eax>
    ENDM

  ; ---------------------------------------
  ; extended formatting version writes text
  ; to the current file pointer location
  ; ---------------------------------------
    ftext MACRO hFile:REQ,args:VARARG
      push esi                              ;; preserve ESI
      mov esi, alloc(16384)                 ;; allocate 16k of buffer
      catargs ftext,esi,args                ;; write ALL args to a single string
      push eax                              ;; make 4 bytes on the stack
      invoke WriteFile,hFile,esi,len(esi),esp,NULL
      pop eax                               ;; release the 4 bytes
      free esi                              ;; free the memory buffer
      pop esi                               ;; restore ESI
    ENDM

  ; -----------------------
  ; test if file exists
  ; return values
  ; 1 = file exists
  ; 0 = file does not exist
  ; -----------------------
    fexist MACRO name_of_file
      IFNDEF __UNICODE__
        EXITM <rv(exist,name_of_file)>
      ELSE
        EXITM <rv(existW,name_of_file)>
      ENDIF
    ENDM
  ; -----------------------

  ; ----------------------------------------------------------
  ; function position macros that takes a DWORD parameter and
  ; returns the address of the buffer that holds the result.
  ; The return format is for use within the INVOKE syntax.
  ; ----------------------------------------------------------
    str$ MACRO DDvalue
      LOCAL rvstring
      .data
        rvstring db 20 dup (0)
        align 4
      .code
      invoke dwtoa,DDvalue,ADDR rvstring
      EXITM <ADDR rvstring>
    ENDM

    hex$ MACRO DDvalue
      LOCAL rvstring
      .data
        rvstring db 12 dup (0)
        align 4
      .code
      invoke dw2hex,DDvalue,ADDR rvstring
      EXITM <ADDR rvstring>
    ENDM

    ; ---------------------------------------------------------------
    ; Get command line arg specified by "argnum" starting at arg 1
    ; Test the return values with the following to determine results
    ; 1 = successful operation
    ; 2 = no argument exists at specified arg number
    ; 3 = non matching quotation marks
    ; 4 = empty quotation marks
    ; test the return value in ECX
    ; ---------------------------------------------------------------

      cmd$ MACRO argnum
        LOCAL argbuffer
        .data?
          argbuffer db MAX_PATH dup (?)
        .code
        invoke GetCL,argnum, ADDR argbuffer
        mov ecx, eax
        mov eax, OFFSET argbuffer
        EXITM <eax>
      ENDM

  ; --------------------------------------------------------
  ; Get the UNICODE command line argument specified by the
  ; 1 based argument number. 1 = arg1, 2 = arg2 etc ....
  ;
  ; The result is returned as an OFFSET to a buffer.
  ;
  ; Testing RETURN VALUES in EAX
  ; < 0 = buffer not large enough for selected arg
  ;   0 = arg not found
  ; > 0 = arg number read from command tail
  ;
  ; NOTE that a negative return value in EAX indicates
  ; buffer over-run protection if and when a command line is
  ; longer than the MAX_PATH constant.
  ; --------------------------------------------------------

      ucCmd$ MACRO argnum
        IFNDEF ucl_@_buffer
          .data?
            uc_@_cl_@_buffer TCHAR MAX_PATH dup (?)
          .code
          ucl_@_buffer equ 1
        ENDIF 
        fn ucGetCL,OFFSET uc_@_cl_@_buffer,MAX_PATH,argnum
        EXITM <OFFSET uc_@_cl_@_buffer>
      ENDM


    ; **************************
    ; memory allocation macros *
    ; **************************

    comment * --------------------------------------------------    
            Two macros for allocating and freeing OLE memory.
            stralloc returns the handle/address of the string
            memory in eax. alloc$ acts in the same way but is
            used in the function position. strfree uses the
            handle to free memory after use.
    
            NOTE that you must use the following INCLUDE &
            LIB files with these two macros.
    
            include \MASM32\include\oleaut32.inc
            includelib \MASM32\LIB\oleaut32.lib
            -------------------------------------------------- *

      alloc$ MACRO ln
        invoke SysAllocStringByteLen,0,ln
        mov BYTE PTR [eax], 0
        EXITM <eax>
      ENDM

      free$ MACRO strhandle
        invoke SysFreeString,strhandle
      ENDM

      stralloc MACRO ln
        invoke SysAllocStringByteLen,0,ln
      ENDM

      strfree MACRO strhandle
        invoke SysFreeString,strhandle
      ENDM

comment * ------------------------------------------------
    The following 2 macros are for general purpose memory
    allocation where fine granularity in memory is required
    or where the memory attribute "execute" is useful.
    ------------------------------------------------------ *

      alloc MACRO bytecount
        invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,bytecount
        EXITM <eax>
      ENDM

      free MACRO hmemory
        invoke GlobalFree,hmemory
      ENDM

comment * ---------------------------------------------------------
        Heap allocation and deallocation macros. On later versions
        of Windows HeapAlloc() appears to be faster on small
        allocations than GlobalAlloc() using the GMEM_FIXED flag.
        --------------------------------------------------------- *

      halloc MACRO bytecount
        EXITM <rv(HeapAlloc,rv(GetProcessHeap),0,bytecount)>
      ENDM

      hsize MACRO hmem
        invoke HeapSize,rv(GetProcessHeap),0,hmem
        EXITM <eax>
      ENDM

      hfree MACRO memory
        invoke HeapFree,rv(GetProcessHeap),0,memory
      ENDM

    ; ************************************************************
    ;                      File Input macros                     *
    ;                                                            *
    ; 3 versions are presented here.                             *
    ;                                                            *
    ; 1. InputFile      determined by the __UNICODE__ equate.    *
    ; 2. InputFileA     ASCII only version.                      *
    ; 3. InputFileW     UNICODE only version.                    *
    ;                                                            *
    ; NOTE: With the address returned by InputFile that contains *
    ; the data in the file, it must be deallocated using the API *
    ; function GlobalFree() or the macro "free".                 *
    ; EXAMPLE: invoke GlobalFree,pMem                            *
    ;                                                            *
    ; If you specify either the ASCII or UNICODE version of the  *
    ; macro you must match the text type for the file name       *
    ; to the macro being called.                                 *
    ;                                                            *
    ; For ASCII use the "ascii()" macro.                         *
    ; for UNICODE use either the "uni$()" or the "uc$()" macro.  *
    ;                                                            *
    ; If you are providing an address instead of a literal       *
    ; string, the text must be in the matching format for either *
    ; ASCII or UNICODE.                                          *
    ;                                                            *
    ; ************************************************************

      InputFileA MACRO lpFile
      ;; ----------------------------------------------------------
      ;; The untidy data? names are to avoid duplication in normal
      ;; code. The two values are reused by each call to the macro
      ;; ----------------------------------------------------------
        IFNDEF ipf@@flagA           ;; if the flag is not defined
          .data?
            ipf@__@mem@__@PtrA dd ? ;; write 2 DWORD variables to
            ipf@__file__@lenA dd ?  ;; the uninitialised data section
          .code
          ipf@@flagA equ <1>        ;; define the flag
        ENDIF

        invoke read_disk_file,reparg(lpFile),
               ADDR ipf@__@mem@__@PtrA,
               ADDR ipf@__file__@lenA

        mov ecx, ipf@__file__@lenA   ;; file length returned in ECX
        mov eax, ipf@__@mem@__@PtrA  ;; address of memory returned in EAX
        EXITM <eax>
      ENDM

      InputFileW MACRO lpFile
      ;; ----------------------------------------------------------
      ;; The untidy data? names are to avoid duplication in normal
      ;; code. The two values are reused by each call to the macro
      ;; ----------------------------------------------------------
        IFNDEF ipf@@flagW           ;; if the flag is not defined
          .data?
            ipf@__@mem@__@PtrW dd ? ;; write 2 DWORD variables to
            ipf@__file__@lenW dd ?  ;; the uninitialised data section
          .code
          ipf@@flagW equ <1>        ;; define the flag
        ENDIF

        invoke read_disk_fileW,reparg(lpFile),
               ADDR ipf@__@mem@__@PtrW,
               ADDR ipf@__file__@lenW

        mov ecx, ipf@__file__@lenW  ;; file length returned in ECX
        mov eax, ipf@__@mem@__@PtrW ;; address of memory returned in EAX
        EXITM <eax>
      ENDM

      InputFile MACRO lpFile
        IFNDEF __UNICODE__
          EXITM <InputFileA(lpFile)>
        ENDIF
        EXITM <InputFileW(lpFile)>
      ENDM

    ; ************************************************************
    ;                     File Output macros                     *
    ;                                                            *
    ; 3 versions are presented here.                             *
    ;                                                            *
    ; 1. OutputFile     determined by the __UNICODE__ equate.    *
    ; 2. OutputFileA    ASCII only version                       *
    ; 3. OutputFileW    UNICODE only version                     *
    ;                                                            *
    ; If you specify either the ASCII or UNICODE version of the  *
    ; macro you must match the text type for the file name       *
    ; to the macro being called.                                 *
    ;                                                            *
    ; For ASCII use the "ascii()" macro.                         *
    ; for UNICODE use either the "uni$()" or the "uc$()" macro.  *
    ;                                                            *
    ; If you are providing an address instead of a literal       *
    ; string, the text must be in the matching format for either *
    ; ASCII or UNICODE.                                          *
    ;                                                            *
    ; ************************************************************

      OutputFileA MACRO lpFile,lpMem,lof
        invoke write_disk_file,reparg(lpFile),lpMem,lof
        EXITM <eax>
      ENDM

      OutputFileW MACRO lpFile,lpMem,lof
        invoke write_disk_fileW,reparg(lpFile),lpMem,lof
        EXITM <eax>
      ENDM

      OutputFile MACRO lpFile,lpMem,lof
        IFNDEF __UNICODE__
          invoke write_disk_file,reparg(lpFile),lpMem,lof
          EXITM <eax>
        ENDIF
        invoke write_disk_fileW,reparg(lpFile),lpMem,lof
        EXITM <eax>
      ENDM

    ; -----------------------------------------
    ; common dialog file open and close macros.
    ; Return value in both is the OFFSET of a
    ; 260 byte dedicated buffer in the .DATA?
    ; section in EAX.
    ; -----------------------------------------
      OpenFileDlg MACRO hWin,hInstance,lpTitle,lpPattern
        invoke OpenFileDialog,hWin,hInstance,reparg(lpTitle),reparg(lpPattern)
        EXITM <eax>
      ENDM

      SaveFileDlg MACRO hWin,hInstance,lpTitle,lpPattern
        invoke SaveFileDialog,hWin,hInstance,reparg(lpTitle),reparg(lpPattern)
        EXITM <eax>
      ENDM

    ; ----------------------------------------------------------
    ; load a library and get the procedure address in one macro
    ; return value for the proc address in in EAX. Both DLL and
    ; procedure name are enclosed in quotation marks.
    ;
    ; EXAMPLE : LoadProcAddress "mydll.dll","myproc"
    ;           proc address in EAX
    ;           library handle in ECX
    ;
    ; EXAMPLE : mov lpProc, GetDllProc("mydll.dll","myproc")
    ;           library handle in ECX
    ; ----------------------------------------------------------

      LoadProcAddress MACRO libname_text1,procname_text2
        LOCAL library_name
        LOCAL proc_name
          .data
            library_name db libname_text1,0
            proc_name db procname_text2,0
          align 4
          .code
        invoke LoadLibrary,ADDR library_name
        mov ecx, eax
        invoke GetProcAddress,eax,ADDR proc_name
      ENDM

      GetDllProc MACRO libname_text1,procname_text2
        LOCAL library_name
        LOCAL proc_name
          .data
            library_name db libname_text1,0
            proc_name db procname_text2,0
          align 4
          .code
        invoke LoadLibrary,ADDR library_name
        mov ecx, eax
        invoke GetProcAddress,eax,ADDR proc_name
        EXITM <eax>
      ENDM

    ; **********************************
    ; control flow macro by Greg Falen *
    ; **********************************

    ; ----------------------
    ; Switch/Case emulation
    ; ----------------------
    $casflg equ <>
    $casvar equ <>
    $casstk equ <>
    
    switch macro _var:req, _reg:=<eax>
        mov _reg, _var
        $casstk catstr <_reg>, <#>, $casflg, <#>, $casstk
        $casvar equ _reg
        $casflg equ <0>         ;; 0 = emit an .if, 1 an .elseif
    endm
    
    case macro _args:vararg     ;; like Pascal: case id1. id4 .. id8, lparam, ...
                                ;; does an or (case1 || case2 || case3...)
      $cas textequ <>
      irp $v, <_args>         ;; for each case
          t@ instr <$v>, <..> ;; range ?
          if t@               ;; yes
              $LB substr <$v>, 1, t@-1                  ;; lbound = left portion
              $LB catstr <(>, $casvar, <!>=>, $LB, <)>  ;; ($casvar >= lbound)
              $UB substr <$v>, t@+2                     ;; ubound = right portion
              $UB catstr <(>, $casvar, <!<=>, $UB, <)>  ;; ($casvar <= ubound)
              $t catstr <(>, $LB, <&&> , $UB,<)>        ;; (($casvar >= $lb) && ($casvar <= $ub))
          else    ;; no, it's a value (var/const)
              $t catstr <(>, $casvar, <==>, <$v>, <)>   ;; ($casvar == value)
          endif
          $cas catstr <|| >, $t, $cas                   ;; or this case w/ others
      endm
      $cas substr $cas, 3 ;; lose the extra "|| " in front
        ifidn $casflg, <0> ;; 0 = 1'st case
            % .if $cas ;; emit ".if"
        else ;; all others
            % .elseif $cas ;; emit ".elseif"
        endif
        $casflg equ <1> ;; NOT 1'st
    endm
    
    default macro _default:vararg
        .else
        _default
    endm
    
    endsw macro _cmd:vararg
        ifidn $casstk, <>
            .err <Endsw w/o Switch>
        else
            t@ instr $casstk, <#>
            $casvar substr $casstk, 1, t@-1
            $casstk substr $casstk, t@+1
            t@ instr $casstk, <#>
            $casflg substr $casstk, 1, t@-1
            ifidn $casstk, <#>
                $casstk equ <>
            else
                $casstk substr $casstk, t@+1
            endif
            .endif
        endif
    endm

  ; --------------------------------------------------
  ; equates for name and case variation in macro names
  ; --------------------------------------------------
    Case equ <case>
    CASE equ <case>
    Switch equ <switch>
    SWITCH equ <switch>

    Endsw equ <endsw>
    EndSw equ <endsw>
    ENDSW equ <endsw>

    Select equ <switch>
    ;; select equ <switch>
    SELECT equ <switch>

    Endsel equ <endsw>
    endsel equ <endsw>
    ENDSEL equ <endsw>

    Default equ <default>
    DEFAULT equ <default>

    CaseElse equ <default>
    Caseelse equ <default>
    CASEELSE equ <default>
    caseelse equ <default>

comment * ------------------------------------------------
        The following macro system for a string comparison
        switch block was designed by Michael Webster.
        --------------------------------------------------
SYNTAX:

    switch$ string_address          ; adress of zero terminated string

      case$ "quoted text"           ; first string to test against
        ; your code here

      case$ "another quoted text"   ; optional additional quoted text
        ; your code here

      else$                         ; optional default processing
        ; default code here

    endsw$

        ------------------------------------------------ *

; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««
; Macros for storing and retrieving text macros, based on
; the $casstk code from Greg Falen's Switch/Case macros.
; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

    $text_stack$ equ <#>

    pushtext MACRO name:req
        $text_stack$ CATSTR <name>, <#>, $text_stack$
    ENDM

    poptext MACRO name:req
        LOCAL pos
        pos INSTR $text_stack$, <#>
        name SUBSTR $text_stack$, 1, pos-1
        $text_stack$ SUBSTR $text_stack$, pos+1
    ENDM

; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««
; Macros to implement a string-comparison specific
; Switch/Case construct. Multiple instances and
; nesting supported.
; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

    $test_val$ equ <>
    $end_sw$ equ <>
    $sw_state$ equ <>
    _sw_cnt_ = 0

    switch$ MACRO lpstring:REQ
        pushtext $test_val$                 ;; Preserve globals for previous Switch/Case.
        pushtext $sw_state$
        pushtext $end_sw$

        $test_val$ equ <lpstring>           ;; Copy string address for this Select/Case
                                            ;; to global so case$ can access it.             
        $sw_state$ equ <>                   ;; Set state global to starting value.
        _sw_cnt_ = _sw_cnt_ + 1             ;; Generate a unique exit label for this
        $end_sw$ CATSTR <end_sw>, %_sw_cnt_ ;; Select/Case and preserve it.
        pushtext $end_sw$
    ENDM

    case$ MACRO quoted_text:REQ
        ;; The case statements will be any statements between the case$ and the following case$,
        ;; else$, or endsw$.
        ;;
        ;; If this is a following case$, emit a jump to the exit label for this Select/Case and
        ;; terminate the .IF block.
        ;; --------------------------------
        IFIDN $sw_state$, <if>
          poptext $end_sw$                  ;; Because there could have been an intervening
          pushtext $end_sw$                 ;; Switch/Case we need to recover the correct
          jmp   $end_sw$                    ;; exit label for this Switch/Case.
          .ENDIF
        ENDIF
        ;; --------------------------------
        ;; Start a new .IF block and update the state global.


        IFNDEF __UNICODE__
          .IF rv(szCmp, $test_val$, chr$(quoted_text)) != 0
        ELSE
          .IF rv(ucCmp, $test_val$, chr$(quoted_text)) != 0
        ENDIF


        $sw_state$ equ <if>
    ENDM

    else$ MACRO
        IFIDN $sw_state$, <if>              ;; If following a case$, emit a jump to the exit
          poptext $end_sw$                  ;; label for this Select/Case and terminate the .IF
          pushtext $end_sw$                 ;; block. The jump is necessary, whenever the case
          jmp   $end_sw$                    ;; for the .IF block being terminated is true, to
          .ENDIF                            ;; bypass the else statements that follow.
          $sw_state$ equ <>                 ;; The state global must be updated to stop the
        ENDIF                               ;; endsw$ from terminatinmg the .IF block.
    ENDM

    endsw$ MACRO
        IFIDN $sw_state$, <if>              ;; If following a case$, terminate the .IF block.
          .ENDIF
        ENDIF

        poptext $end_sw$                    ;; Remove the exit label from the stack.

      $end_sw$:

        poptext $end_sw$                    ;; Recover gobals for previous Switch/Case.
        poptext $sw_state$
        poptext $test_val$
    ENDM

; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

comment * ----------------------------------------------------
        The following macro system for a string comparison
        switch block was designed by Michael Webster. It has
        been slightly modified for case INSENSITIVE comparison.
        ----------------------------------------------------- *

; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««
; Macros for storing and retrieving text macros, based on
; the $casstk code from Greg Falen's Switch/Case macros.
; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

    $text_stacki$ equ <#>

    pushtexti MACRO name:req
        $text_stacki$ CATSTR <name>, <#>, $text_stacki$
    ENDM

    poptexti MACRO name:req
        LOCAL pos
        pos INSTR $text_stacki$, <#>
        name SUBSTR $text_stacki$, 1, pos-1
        $text_stacki$ SUBSTR $text_stacki$, pos+1
    ENDM

; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««
; Macros to implement a string-comparison specific
; Switch/Case construct. Multiple instances and
; nesting supported.
; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

    $test_vali$ equ <>
    $end_swi$ equ <>
    $sw_statei$ equ <>
    _sw_cnti_ = 0

    switchi$ MACRO lpstring:REQ

        pushtexti $test_vali$                ;; Preserve globals for previous Switch/Case.
        pushtexti $sw_statei$
        pushtexti $end_swi$

        $test_vali$ equ <lpstring>           ;; Copy string address for this Select/Case
                                             ;; to global so case$ can access it.             
        $sw_statei$ equ <>                   ;; Set state global to starting value.
        _sw_cnti_ = _sw_cnti_ + 1            ;; Generate a unique exit label for this
        $end_swi$ CATSTR <end_swi>, %_sw_cnt_ ;; Select/Case and preserve it.
        pushtexti $end_swi$
    ENDM

    casei$ MACRO quoted_text:REQ
        ;; The case statements will be any statements between the case$ and the following case$,
        ;; else$, or endsw$.
        ;;
        ;; If this is a following case$, emit a jump to the exit label for this Select/Case and
        ;; terminate the .IF block.
        ;; --------------------------------
        IFIDN $sw_statei$, <if>
          poptexti $end_swi$                 ;; Because there could have been an intervening
          pushtexti $end_swi$                ;; Switch/Case we need to recover the correct
          jmp   $end_swi$                    ;; exit label for this Switch/Case.
          .ENDIF
        ENDIF
        ;; --------------------------------
        ;; Start a new .IF block and update the state global.

        ;; *******************************************
        IFNDEF __UNICODE__
          .if rv(Cmpi,$test_vali$,chr$(quoted_text)) == 0
        ELSE
          .if rv(lstrcmpi,$test_vali$,chr$(quoted_text)) == 0
        ENDIF
        ;; *******************************************

        $sw_statei$ equ <if>
    ENDM

    elsei$ MACRO
        IFIDN $sw_statei$, <if>              ;; If following a case$, emit a jump to the exit
          poptexti $end_swi$                 ;; label for this Select/Case and terminate the .IF
          pushtexti $end_swi$                ;; block. The jump is necessary, whenever the case
          jmp   $end_swi$                    ;; for the .IF block being terminated is true, to
          .ENDIF                             ;; bypass the else statements that follow.
          $sw_statei$ equ <>                 ;; The state global must be updated to stop the
        ENDIF                                ;; endsw$ from terminatinmg the .IF block.
    ENDM

    endswi$ MACRO
        IFIDN $sw_statei$, <if>              ;; If following a case$, terminate the .IF block.
          .ENDIF
        ENDIF

        poptexti $end_swi$                   ;; Remove the exit label from the stack.

      $end_swi$:

        poptexti $end_swi$                   ;; Recover gobals for previous Switch/Case.
        poptexti $sw_statei$
        poptexti $test_vali$
    ENDM

; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««


    ; -------------------------------------------------------------------
    ; The following 2 macros are for limiting the size of a window while
    ; it is being resized. They are to be used in the WM_SIZING message.
    ; -------------------------------------------------------------------
    LimitWindowWidth MACRO wdth
        LOCAL label
        mov eax, lParam
        mov ecx, (RECT PTR [eax]).right
        sub ecx, (RECT PTR [eax]).left
        cmp ecx, wdth
        jg label
      .if wParam == WMSZ_RIGHT || wParam == WMSZ_BOTTOMRIGHT || wParam == WMSZ_TOPRIGHT
        mov ecx, (RECT PTR [eax]).left
        add ecx, wdth
        mov (RECT PTR [eax]).right, ecx
      .elseif wParam == WMSZ_LEFT || wParam == WMSZ_BOTTOMLEFT || wParam == WMSZ_TOPLEFT
        mov ecx, (RECT PTR [eax]).right
        sub ecx, wdth
        mov (RECT PTR [eax]).left, ecx
      .endif
      label:
    ENDM

    LimitWindowHeight MACRO whgt
        LOCAL label
        mov eax, lParam
        mov ecx, (RECT PTR [eax]).bottom
        sub ecx, (RECT PTR [eax]).top
        cmp ecx, whgt
        jg label
      .if wParam == WMSZ_TOP || wParam == WMSZ_TOPLEFT || wParam == WMSZ_TOPRIGHT
        mov ecx, (RECT PTR [eax]).bottom
        sub ecx, whgt
        mov (RECT PTR [eax]).top, ecx
      .elseif wParam == WMSZ_BOTTOM || wParam == WMSZ_BOTTOMLEFT || wParam == WMSZ_BOTTOMRIGHT
        mov ecx, (RECT PTR [eax]).top
        add ecx, whgt
        mov (RECT PTR [eax]).bottom, ecx
      .endif
      label:
    ENDM

    MsgBox MACRO hndl,txtmsg,titlemsg,styl
      invoke MessageBox,hndl,reparg(txtmsg),reparg(titlemsg),styl
    ENDM

    ; ************************************
    ; console mode text input and output *
    ; ************************************

    cls MACRO                       ;; clear screen
      invoke ClearScreen
    ENDM

    print MACRO arg1:REQ,varname:VARARG      ;; display zero terminated string
        IFNDEF __UNICODE__
          invoke StdOut,expand_prefix(reparg(arg1))
        ELSE
          invoke StdOutW,expand_prefix(reparg(arg1))
        ENDIF
      IFNB <varname>
        IFNDEF __UNICODE__
          invoke StdOut,chr$(varname)
        ELSE
          invoke StdOutW,chr$(varname)
        ENDIF
      ENDIF
    ENDM

    printc MACRO text:VARARG
      print cfm$(text)
    ENDM

    ccout MACRO text:VARARG
      print cfm$(text)
    ENDM

comment * -----------------------------------------
        Extended version of "print" with additional
        character notation support.
        
          n = newline
          t = tab
          q = quote
          lb = (
          rb = )
          la = <
          ra = >

        ----------------------------------------- *

    cprint MACRO args:VARARG
      push esi
      mov esi, alloc(16384)
      catargs cprint,esi,args
      invoke StdOut,esi
      free esi
      pop esi
    ENDM

    write MACRO quoted_text:VARARG  ;; display quoted text
      LOCAL txt
      .data
        txt db quoted_text,0
        align 4
      .code
      invoke StdOut,ADDR txt
    ENDM

    loc MACRO xc,yc                 ;; set cursor position
      invoke locate,xc,yc
    ENDM

comment * -------------------------------------

    use the "input" macro as follows,

    If you want a prompt use this version
    mov lpstring, input("Type text here : ")

    If you don't need a prompt use the following
    mov lpstring, input()

    NOTE : The "lpstring" is a preallocated
           DWORD variable that is either LOCAL
           or declared in the .DATA or .DATA?
           section. Any legal name is OK.

    LIMITATION : MASM uses < > internally in its
    macros so if you wish to use these symbols
    in a prompt, you must use the ascii value
    and not use the symbol literally.

    EXAMPLE mov var, input("Enter number here ",62," ")

    ------------------------------------------- *

    input MACRO prompt:VARARG
      LOCAL txt
      LOCAL buffer
      IFNB <prompt>
        .data
          txt db prompt, 0
          align 4
        .data?
          buffer TCHAR 260 dup (?)
          align 4
        .code
        IFNDEF __UNICODE__
          invoke StdOut,ADDR txt
          invoke StdIn,ADDR buffer,260
        ELSE
          invoke StdOutW,uni$(prompt)
          invoke StdInW,ADDR buffer,260
        ENDIF
        EXITM <OFFSET buffer>
      ELSE
        .data?
          buffer TCHAR 260 dup (?)
          align 4
        .code
        IFNDEF __UNICODE__
          invoke StdIn,ADDR buffer,260
        ELSE
          invoke StdInW,ADDR buffer,260
        ENDIF
        EXITM <OFFSET buffer>
      ENDIF
    ENDM

  ; --------------------------------------------------------
  ; exit macro with an optional return value for ExitProcess
  ; --------------------------------------------------------
    exit MACRO optional_return_value
      IFNDEF optional_return_value
        invoke ExitProcess, 0
      ELSE
        invoke ExitProcess,optional_return_value
      ENDIF
    ENDM

    ;; ------------------------------------------------------
    ;; display user defined text, default text or none if
    ;; NULL is specified and wait for a keystroke to continue
    ;; ------------------------------------------------------
    inkey MACRO user_text:VARARG
      IFDIF <user_text>,<NULL>                  ;; if user text not "NULL"
        IFNB <user_text>                        ;; if user text not blank
          print user_text                       ;; print user defined text
        ELSE                                    ;; else
          print "Press any key to continue ..." ;; print default text
        ENDIF
      ENDIF
      call wait_key
      print chr$(13,10)
    ENDM

    ;; ---------------------------------------------------
    ;; wait for a keystroke and return its scancode in EAX
    ;; ---------------------------------------------------
    getkey MACRO
      call ret_key
    ENDM

    SetConsoleCaption MACRO title_text:VARARG
      invoke SetConsoleTitle,reparg(title_text)
    ENDM

    GetConsoleCaption$ MACRO
      IFNDEF @@_console_caption_buffer_@@
      .data?
        @@_console_caption_buffer_@@ db 260 dup (?)
      .code
      ENDIF
      invoke GetConsoleTitle,ADDR @@_console_caption_buffer_@@,260
      EXITM <OFFSET @@_console_caption_buffer_@@>
    ENDM


    ; **************************
    ; Application startup code *
    ; **************************

      AppStart MACRO
        .code
        start:
        invoke GetModuleHandle, NULL
        mov hInstance, eax

        invoke GetCommandLine
        mov CommandLine, eax

        invoke InitCommonControls

        invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
        invoke ExitProcess,eax
      ENDM

    ; --------------------------------------------------------------
    ; Specifies processor, memory model & case sensitive option.
    ; The parameter "Processor" should be in the form ".386" etc..
    ; EXAMPLE : AppModel .586
    ; --------------------------------------------------------------
      AppModel MACRO Processor
        Processor             ;; Processor type
        .model flat, stdcall  ;; 32 bit memory model
        option casemap :none  ;; case sensitive
      ENDM

    ; --------------------------------------------
    ; The following two macros must be used as a
    ; pair and can only be used once in a module.
    ; Additional code for processing within the
    ; message loop can be placed between them.
    ;
    ; The single parameter passed to both macros
    ; is the name of the MSG structure and must be
    ; the same in both macros.
    ; --------------------------------------------

      BeginMessageLoop MACRO mStruct
        MessageLoopStart:
          invoke GetMessage,ADDR mStruct,NULL,0,0
          cmp eax, 0
          je MessageLoopExit
      ENDM

      EndMessageLoop MACRO mStruct
          invoke TranslateMessage, ADDR mStruct
          invoke DispatchMessage,  ADDR mStruct
          jmp MessageLoopStart
        MessageLoopExit:
      ENDM

    ; ********************************************
    ; align memory                               *
    ; reg has the address of the memory to align *
    ; number is the required alignment           *
    ; EXAMPLE : memalign esi, 16                 *
    ; ********************************************

      memalign MACRO reg, number
        add reg, number - 1
        and reg, -number
      ENDM

; ---------------------------------------------------------------------
;
; The GLOBALS macro is for allocating uninitialised data in the .DATA?
; section. It is designed to take multiple definitions to make
; allocating uninitialised data more intuitive while coding.
;
; EXAMPLE: GLOBALS item1 dd ?,\
;                  item2 dd ?,\
;                  item3 dw ?,\
;                  item4 db 128 dup (?)
;
; ---------------------------------------------------------------------

      GLOBALS MACRO var1,var2,var3,var4,var5,var6,var7,var8,var9,var0,
                    varA,varB,varC,varD,varE,varF,varG,varH,varI,varJ
        .data?
          align 4
          var1
          var2
          var3
          var4
          var5
          var6
          var7
          var8
          var9
          var0
          varA
          varB
          varC
          varD
          varE
          varF
          varG
          varH
          varI
          varJ
        .code
      ENDM

    ; **********************
    ; miscellaneous macros *
    ; **********************

      ShellAboutBox MACRO handle,IconHandle,quoted_Text_1,quoted_Text_2:VARARG
        LOCAL AboutTitle,AboutMsg,buffer

        .data
          align 4
          buffer db 128 dup (0)
          AboutTitle db quoted_Text_1,0
          AboutMsg   db quoted_Text_2,0
          align 4
        .code

        mov esi, offset AboutTitle
        mov edi, offset buffer
        mov ecx, lengthof AboutTitle
        rep movsb
        
        invoke ShellAbout,handle,ADDR buffer,ADDR AboutMsg,IconHandle
      ENDM

; ------------------------------------------------------------------
; macro for making STDCALL procedure and API calls.
; ------------------------------------------------------------------

    Scall MACRO name:REQ,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12, \
                     p13,p14,p15,p16,p17,p18,p19,p20,p21,p22

    ;; ---------------------------------------
    ;; loop through arguments backwards, push
    ;; NON blank ones and call the function.
    ;; ---------------------------------------

      FOR arg,<p22,p21,p20,p19,p18,p17,p16,p15,p14,p13,\
               p12,p11,p10,p9,p8,p7,p6,p5,p4,p3,p2,p1>
        IFNB <arg>    ;; If not blank
          push arg    ;; push parameter
        ENDIF
      ENDM

      call name       ;; call the procedure

    ENDM

    ; -------------------------------
    ; pascal calling convention macro
    ; left to right push
    ; -------------------------------
      Pcall MACRO name:REQ,items:VARARG
        LOCAL arg
        FOR arg,<items>
          push arg
        ENDM
          call name
      ENDM

    ; ---------------------------------------
    ; Append literal string to end of buffer
    ; ---------------------------------------
      Append MACRO buffer,text
        LOCAL szTxt
        .data
          szTxt db text,0
          align 4
        .code
        invoke szCatStr,ADDR buffer,ADDR szTxt
      ENDM

    ; ---------------------------
    ; Put ascii zero at 1st byte
    ; ---------------------------
      zero1 MACRO membuf
        mov membuf[0], 0
      ENDM

    ; -------------------------------------------
    ; put zero terminated string in .data section
    ; alternative to the szText MACRO
    ; -------------------------------------------
      dsText MACRO Name, Text:VARARG
      .data
        Name db Text,0
        align 4
      .code
      ENDM

    ; -------------------------------
    ; make 2 WORD values into a DWORD
    ; result in eax
    ; -------------------------------
      MAKEDWORD MACRO LoWord,HiWord
        mov ax, HiWord
        ror eax, 16
        mov ax, LoWord
      ENDM

    ; -----------------------------
    ; return IMMEDIATE value in eax
    ; -----------------------------
      retval MACRO var
        IF var EQ 0
          xor eax, eax  ;; slightly more efficient for zero
        ELSE
          mov eax, var  ;; place value in eax
        ENDIF
        ret
      ENDM

    ; ------------------------
    ; inline memory copy macro
    ; ------------------------
      Mcopy MACRO lpSource,lpDest,len
        mov esi, lpSource
        mov edi, lpDest
        mov ecx, len
        rep movsb
      ENDM

    ; -----------------------------------
    ; INPUT red, green & blue BYTE values
    ; OUTPUT DWORD COLORREF value in eax
    ; -----------------------------------
      RGB MACRO red, green, blue
        xor eax, eax
        mov ah, blue    ; blue
        mov al, green   ; green
        rol eax, 8
        mov al, red     ; red
      ENDM

    ; ------------------------------------------------
    ; The following macro were written by Ron Thomas
    ; ------------------------------------------------
    ; Retrieves the low word from double word argument
    ; ------------------------------------------------
      LOWORD MACRO bigword  
        mov  eax,bigword
        and  eax,0FFFFh     ;; Set to low word 
      ENDM

    ; ----------------------
    ; fast lodsb replacement
    ; ----------------------
      lob MACRO
        mov al, [esi]
        inc esi
      ENDM

    ; ----------------------
    ; fast stosb replacement
    ; ----------------------
      stb MACRO
        mov [edi], al
        inc edi
      ENDM

    ; ----------------------------
    ; code section text insertion
    ; ----------------------------
      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      return MACRO arg
        mov eax, arg
        ret
      ENDM

      SingleInstanceOnly MACRO lpClassName
        invoke FindWindow,lpClassName,NULL
        cmp eax, 0
        je @F
          push eax
          invoke ShowWindow,eax,SW_RESTORE
          pop eax
          invoke SetForegroundWindow,eax
          mov eax, 0
          ret
        @@:
      ENDM

    ; macro encapsulates the MAX_PATH size buffer and returns its OFFSET

      DropFileName MACRO wordparam
        IFNDEF df@@name
          .data?
            dfname TCHAR MAX_PATH dup (?)
          .code
        df@@name equ 1
        ENDIF
        invoke DragQueryFile,wordparam,0,ADDR dfname,SIZEOF dfname
        EXITM <OFFSET dfname>
      ENDM


    ; returns the handle of a control where its ID is known

      hDlgItem MACRO pHwnd,ctlID
        LOCAL retval
        .data?
          retval dd ?
        .code
        invoke GetDlgItem,pHwnd,ctlID
        mov retval, eax
        EXITM <retval>
      ENDM

  ; ----------------------------------------
  ; chtype$() will accept either a BYTE sized
  ; register or the address of a BYTE as a
  ; memory operand.
  ; The result is returned in a memory operand
  ; as a BYTE PTR to the character class in the
  ; table.
  ; You would normally use this macro with
  ;
  ;     movzx ecx, chtype$([ebp+4])
  ;     cmp chtype$([esp+4]), 2
  ;     cmp chtype$(ah), dl
  ;
  ; ----------------------------------------
    chtype$ MACRO character
      IFNDEF chtyptbl
        EXTERNDEF chtyptbl:DWORD         ;; load table if not already loaded
      ENDIF
      movzx eax, BYTE PTR character      ;; zero extend character to 32 bit reg
      EXITM <BYTE PTR [eax+chtyptbl]>    ;; place the table access in a 32 bit memory operand
    ENDM

  ; ********************
  ; Line reading macros.
  ; ********************

    linein$ MACRO source,buffer,spos
      invoke readline,source,buffer,spos
      EXITM <eax>
    ENDM

    lineout$ MACRO source,buffer,spos,op_crlf
      invoke writeline,reparg(source),buffer,spos,op_crlf
      EXITM <eax>
    ENDM

    tstline$ MACRO lpstr
      invoke tstline,reparg(lpstr)
      EXITM <eax>
    ENDM

  ; -----------------------------------
  ; UNICODE string functions and macros
  ; -----------------------------------

    uadd$ MACRO wstr1,wstr2
      invoke ucCatStr,wstr1,wstr2
      EXITM <wstr1>
    ENDM

    uptr$ MACRO lpbuffer
      lea eax, lpbuffer
      mov WORD PTR [eax], 0
      EXITM <eax>
    ENDM

    ucmp$ MACRO wstr1,wstr2
      invoke ucCmp,wstr1,wstr2
      EXITM <eax>
    ENDM

    ucopy$ MACRO wstr1,wstr2
      invoke ucCopy,wstr1,wstr2
    ENDM

    ulen$ MACRO lpwstr
      invoke ucLen,lpwstr
      EXITM <eax>
    ENDM

    ulcase$ MACRO lpwstr
      invoke CharLowerBuffW,lpwstr,ulen$(lpwstr)
      EXITM <lpwstr>
    ENDM

    uucase$ MACRO lpwstr
      invoke CharUpperBuffW,lpwstr,ulen$(lpwstr)
      EXITM <lpwstr>
    ENDM

    uleft$ MACRO lpwstr,ccount
      invoke ucLeft,lpwstr,lpwstr,ccount
      EXITM <lpwstr>
    ENDM

    umid$ MACRO lpwstr,spos,ln
      invoke ucMid,lpwstr,lpwstr,spos,ln
      EXITM <lpwstr>
    ENDM

    uright$ MACRO lpwstr,ccount
      invoke ucRight,lpwstr,lpwstr,ccount
      EXITM <lpwstr>
    ENDM

    urev$ MACRO lpwstr
      invoke ucRev,lpwstr,lpwstr
      EXITM <lpwstr>
    ENDM

    ultrim$ MACRO lpwstr
      invoke ucLtrim,lpwstr,lpwstr
      EXITM <lpwstr>
    ENDM

    urtrim$ MACRO lpwstr
      invoke ucRtrim,lpwstr,lpwstr
      EXITM <lpwstr>
    ENDM

; ¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤=÷=¤

; «««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

    LOCALVAR equ <LOCAL>

    ; ----------------------------------
    ; macros for creating menu bar items
    ; ----------------------------------

    TxtItem MACRO tID, cID, strng
      mov tbb.iBitmap,   I_IMAGENONE
      mov tbb.idCommand, cID
      mov tbb.fsStyle,   BTNS_BUTTON or BTNS_AUTOSIZE
      mov tbb.iString,   tID
      fn SendMessage,TBhWnd,TB_ADDBUTTONS,1,ADDR tbb
      fn SendMessage,TBhWnd,TB_ADDSTRING,0,chr$(strng,0,0)
    ENDM

    ; ------------------------------

    TxtSeperator MACRO
      mov tbb.iBitmap,   I_IMAGENONE
      mov tbb.idCommand, 0
      mov tbb.fsStyle,   BTNS_SEP ;; or BTNS_AUTOSIZE   ; << extra spacing
      invoke SendMessage,TBhWnd,TB_ADDBUTTONS,1,ADDR tbb
    ENDM

    ; ------------------------------

    TB_BEGIND MACRO pHandle

    LOCALVAR TBhWnd    :DWORD
    LOCALVAR tbb       :TBBUTTON

      invoke CreateWindowEx,0,
                            chr$("ToolbarWindow32"),
                            NULL,
                            WS_CHILD or WS_VISIBLE or TBSTYLE_TOOLTIPS or \
                            TBSTYLE_FLAT or TBSTYLE_LIST or \
                            TBSTYLE_TRANSPARENT,
                            0,0,500,20,
                            pHandle,NULL,
                            hInstance,NULL
      mov TBhWnd, eax

      invoke SendMessage,TBhWnd,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
      invoke SendMessage,TBhWnd,TB_SETINDENT,5,0

      mov tbb.fsState,   TBSTATE_ENABLED
      mov tbb.dwData,    0
      mov tbb.iString,   0
    ENDM

    ; ------------------------------

    TB_BEGIN MACRO pHandle

    LOCALVAR TBhWnd    :DWORD
    LOCALVAR tbb       :TBBUTTON

      invoke CreateWindowEx,0,
                            chr$("ToolbarWindow32"),
                            NULL,
                            WS_CHILD or WS_VISIBLE or TBSTYLE_TOOLTIPS or \
                            TBSTYLE_FLAT or TBSTYLE_LIST or \
                            TBSTYLE_TRANSPARENT or CCS_NODIVIDER,
                            0,0,500,20,
                            pHandle,NULL,
                            hInstance,NULL
      mov TBhWnd, eax

      invoke SendMessage,TBhWnd,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
      invoke SendMessage,TBhWnd,TB_SETINDENT,5,0

      mov tbb.fsState,   TBSTATE_ENABLED
      mov tbb.dwData,    0
      mov tbb.iString,   0
    ENDM

    ; ------------------------------

    TB_END MACRO
      mov eax, TBhWnd
      ret
    ENDM

    ; ------------------------------

; «««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««

    date$ MACRO
      IFNDEF @_@_current_local_date_@_@
        .data?
          @_@_current_local_date_@_@ TCHAR 128 dup (?)
        .code
      ENDIF
      invoke GetDateFormat,LOCALE_USER_DEFAULT,DATE_LONGDATE,
                           NULL,NULL,ADDR @_@_current_local_date_@_@,128
      EXITM <OFFSET @_@_current_local_date_@_@>
    ENDM

    time$ MACRO
      IFNDEF @_@_current_local_time_@_@
        .data?
          @_@_current_local_time_@_@ TCHAR 128 dup (?)
        .code
      ENDIF
      invoke GetTimeFormat,LOCALE_USER_DEFAULT,NULL,NULL,NULL,
                           ADDR @_@_current_local_time_@_@,128
      EXITM <OFFSET @_@_current_local_time_@_@>
    ENDM

  ; --------------------------------------------------------
  ; useful macro for adding padding directly in source code.
  ; --------------------------------------------------------
    nops MACRO cnt:REQ
      REPEAT cnt
        nop
      ENDM
    ENDM

comment * -----------------------------------------------------------------

   NOTES on DDPROTO macro

   This macro is for producing prototypes for functions where the start
   address is known and the parameter count is known. It requires a named
   DWORD sized entry in the .DATA or .DATA? section which has the start
   address written to it before the function is called.

        EXAMPLE:
        .data?
          user32_msgbox dd ?            ; << The named variable

        msgbox DDPROTO(user32_msgbox,4) ; create prototype

        This is expanded to the following. The TYPEDEF refers to
        the macro "pr4" in the WINDOWS.INC file.

        pt4 TYPEDEF PTR pr4
        msgbox equ <(TYPE pt4) PTR user32_msgbox>

        The address must be written to the DWORD variable before it can
        be called. This can be LoadLibrary/GetProcAddress or it can be
        an address recovered from a virtual table in a DLL or any other
        viable means of obtaining the start address of a function to call.

        invoke msgbox,hWnd,ADDR message_text, ADDR title_text,MB_OK

        ----------------------------------------------------------------- *

      DDPROTO MACRO lpFunction,pcount
        LOCAL txt1,txt2
        txt1 equ <pr>
        txt1 CATSTR txt1,%pcount
        txt2 equ <pt>
        txt2 CATSTR txt2,%pcount
        txt2 TYPEDEF PTR txt1
        EXITM <equ <(TYPE txt2) PTR lpFunction>>
      ENDM

comment * ==================================================================

     The following macros create a text stack and retrieve text items from
     that stack.

 1.  pushtxt textitem   ; place text item on text stack
 2.  poptxt [lbl]       ; retrieve last text item and write it to the souce file
 3.  poptxt$()          ; return last text item on the stack to caller.

     Both versions of poptxt remove the item from the stack. The optional
     parameter "lbl" for the statement version "poptxt" writes a colon after the
     txt item in the source file so it is a label.

     ptdbg equ <1>   use this equate to display stack text items for debugging macros.

     NOTES : The text stack macros have been tested and are reliable but they are
     subject to undocumented behavour with the characteristics of at least some
     of the internal loop code and similar macro operators. The tested effect under
     a FOR loop is that the main equate that stores the text data as a stack is
     initialised back to an empty string when called from a FOR loop. Where you need loop
     code when using these text stack macros, you are safer using a label and testing
     the variable with an IF operator.

     var = 10               ;; set the variable to a value
   :label                   ;; write a macro label

     ; your macro code here

     var = var - 1          ;; decrement variable
     IF var NE 0            ;; test if its zero
       goto label           ;; jump back to label if its not
     ENDIF

     The mangled names for the string equate and the depth indicator are to reduce
     the chance of a name clash with other symbols used in the source file.

        ================================================================= *

    pushtxt MACRO arg
      IFNDEF @_txt_stack_@
        @_txt_stack_@ equ <>                        ;; allocate text buffer as equate
        @_s_d_i_@ = 0                               ;; allocate stack depth indicator
      ENDIF
      IFNDEF ptdbg
        ptdbg equ <0>                               ;; debug equate, set to 1 for display
      ENDIF
      @_txt_stack_@ CATSTR <arg^>,@_txt_stack_@     ;; prepend new arg to front of stack
      @_s_d_i_@ = @_s_d_i_@ + 1                     ;; increment depth counter
      IF ptdbg
      % echo arg
      ENDIF
    ENDM

    poptxt MACRO extra:VARARG                       ;; "extra" arg if used must be "lbl" (without quotes)
      LOCAL txt,num,sln
      nop
      num INSTR @_txt_stack_@,<^>                   ;; get 1st delimiter location
      num = num + 1
      txt SUBSTR @_txt_stack_@,1,num-2              ;; read text back off stack
      IF ptdbg
      % echo txt
      ENDIF
      @_s_d_i_@ = @_s_d_i_@ - 1                     ;; decrement stack item count
      IF @_s_d_i_@ NE 0                             ;; if stack depth NOT zero
        sln SIZESTR @_txt_stack_@                   ;; get current stack length
        @_txt_stack_@ SUBSTR @_txt_stack_@, \
                             num,sln-num+1          ;; remove current item from stack
      ELSE
        @_txt_stack_@ equ <>                        ;; empty the stack on last arg
      ENDIF
      IFIDNI <lbl>,<extra>
        txt CATSTR txt,<:>                          ;; append a colon if its a label
        txt                                         ;; then write txt to source file
      ELSE
        txt                                         ;; write txt to source file
      ENDIF
    ENDM

    poptxt$ MACRO
      LOCAL txt,num,sln
      num INSTR @_txt_stack_@,<^>                   ;; get 1st delimiter location
      num = num + 1
      txt SUBSTR @_txt_stack_@,1,num-2              ;; read text back off stack
      IF ptdbg
      % echo txt
      ENDIF
      @_s_d_i_@ = @_s_d_i_@ - 1                     ;; decrement stack item count
      IF @_s_d_i_@ NE 0                             ;; if stack depth NOT zero
        sln SIZESTR @_txt_stack_@                   ;; get current stack length
        @_txt_stack_@ SUBSTR @_txt_stack_@, \
                             num,sln-num+1          ;; remove current item from stack
      ELSE
        @_txt_stack_@ equ <>                        ;; empty the stack on last arg
      ENDIF
      EXITM <txt>
    ENDM

 ; *************************************************************************

  ; --------------------------------------
  ; save registers in left to right order.
  ; --------------------------------------
    pushr MACRO regs:VARARG
      LOCAL cnt,lpc,lbl
      cnt = argcount(regs)
      lpc = 0
    :lbl
      pushtxt getarg(lpc+1,regs)
      push getarg(lpc+1,regs)
      lpc = lpc + 1
      IF lpc NE cnt
        goto lbl
      ENDIF
    ENDM

  ; --------------------------------------------
  ; restore the same registers in reverse order.
  ; --------------------------------------------
    popr MACRO
      LOCAL lbl
    :lbl
      pop poptxt$()
      IF @_s_d_i_@ GT 0
        goto lbl
      ENDIF
    ENDM

 ; *************************************************************************

    MakeIP MACRO arg1,arg2,arg3,arg4
        mov ah, arg1
        mov al, arg2
        rol eax, 16
        mov ah, arg3
        mov al, arg4
      EXITM <eax>
    ENDM


comment * -------------------------------------------------

        The "uselib" macro allows names that are used for
        both include files and library file to be used in a
        list without extensions. Note the following order
        of include files where WINDOWS.INC should be
        included first then the main macro file BEFORE this
        macro is called.

        include \masm32\include\windows.inc
        include \masm32\macros\macros.asm
        uselib masm32,gdi32,user32,kernel32,Comctl32,comdlg32,shell32,oleaut32,msvcrt

        ------------------------------------------------- *

    uselib MACRO args:VARARG
      LOCAL acnt,buffer,var,lbl,libb,incc,buf1,buf2
      acnt = argcount(args)
      incc equ <include \masm32\include\>
      libb equ <includelib \masm32\lib\>
      var = 1
    :lbl
      buffer equ getarg(var,args)

      buf1 equ <>
      buf1 CATSTR buf1,incc,buffer,<.inc>
      buf1
      ;; % echo buf1

      buf2 equ <>
      buf2 CATSTR buf2,libb,buffer,<.lib>
      buf2
      ;; % echo buf2

      var = var + 1
      IF var LE acnt
        goto lbl
      ENDIF
    ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

  ; *************************************************
  ; The following numeric to string conversions were
  ; written by Greg Lyon using the "sprintf" function
  ; in the standard C runtime DLL MSVCRT.DLL
  ; *************************************************

    ubyte$ MACRO ubytevalue:req
        ;; unsigned byte
        LOCAL buffer, ubtmp
        .data?
            ubtmp  BYTE ?
            buffer BYTE 4 dup(?)
        IFNDEF ubfmt    
        .data    
            ubfmt  BYTE "%hhu", 0
        ENDIF    
        .code
            IFE issize(ubytevalue, 1)
                echo ----------------------
                echo ubyte$ - requires BYTE
                echo ----------------------
                .ERR
            ENDIF               
            mov    buffer[0], 0
            IF isregister(ubytevalue)
                mov   ubtmp, ubytevalue
                movzx eax, ubtmp
            ELSE
                mov   al, ubytevalue
                movzx eax, al
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR ubfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sbyte$ MACRO sbytevalue:req
        ;; signed byte
        LOCAL buffer, sbtmp
        .data?
            sbtmp  SBYTE ?
            buffer BYTE  8 dup(?)
        IFNDEF sbfmt     
        .data    
            sbfmt  BYTE "%hhd", 0
        ENDIF    
        .code
            IFE issize(sbytevalue, 1)
                echo -----------------------
                echo sbyte$ - requires SBYTE
                echo -----------------------
                .ERR
            ENDIF               
            mov    buffer[0], 0
            IF isregister(sbytevalue)
                mov   sbtmp, sbytevalue
                movsx eax, sbtmp
            ELSE     
                mov   al, sbytevalue
                movsx eax, al
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR sbfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xbyte$ MACRO xbytevalue:req
        ;; unsigned hex byte
        LOCAL buffer, xbtmp
        .data?
            xbtmp  BYTE ?
            buffer BYTE 4 dup(?)
        IFNDEF xbfmt    
        .data    
            xbfmt  BYTE "%hhX", 0
        ENDIF    
        .code
            IFE issize(xbytevalue, 1)
                echo ----------------------
                echo xbyte$ - requires BYTE
                echo ----------------------
                .ERR
            ENDIF                
            mov buffer[0], 0
            IF isregister(xbytevalue)
                mov   xbtmp, xbytevalue
                movzx eax, xbtmp
            ELSE
                mov   al, xbytevalue
                movzx eax, al
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR xbfmt, eax 
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    uword$ MACRO uwordvalue:req
        ;; unsigned word
        LOCAL buffer, uwtmp
        .data?
            uwtmp  WORD ?
            buffer BYTE 8 dup(?)
        IFNDEF uwfmt    
        .data    
            uwfmt  BYTE "%hu", 0
        ENDIF    
        .code
            IFE issize(uwordvalue, 2)
                echo ----------------------
                echo uword$ - requires WORD
                echo ----------------------
                .ERR
            ENDIF            
            mov   buffer[0], 0
            IF isregister(uwordvalue)
                mov   uwtmp, uwordvalue
                movzx eax, uwtmp
            ELSE       
                mov   ax, uwordvalue
                movzx eax, ax
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR uwfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sword$ MACRO swordvalue:req
        ;; signed word
        LOCAL buffer, swtmp
        .data?
            swtmp  SWORD ? 
            buffer BYTE  8 dup(?)
        IFNDEF swfmt    
        .data    
            swfmt  BYTE "%hd", 0
        ENDIF    
        .code
            IFE issize(swordvalue, 2)
                echo -----------------------
                echo sword$ - requires SWORD
                echo -----------------------
                .ERR
            ENDIF            
            mov   buffer[0], 0
            IF isregister(swordvalue)
                mov   swtmp, swordvalue
                movsx eax, swtmp
            ELSE    
                mov   ax, swordvalue
                movsx eax, ax
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR swfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xword$ MACRO xwordvalue:req
        ;; unsigned hex word
        LOCAL buffer, xwtmp
        .data?
            xwtmp  WORD ?
            buffer BYTE 8 dup(?)
        IFNDEF xwfmt    
        .data    
            xwfmt  BYTE "%hX", 0
        ENDIF    
        .code
            IFE issize(xwordvalue, 2)
                echo ----------------------
                echo xword$ - requires WORD
                echo ----------------------
                .ERR
            ENDIF        
            mov   buffer[0], 0
            IF isregister(xwordvalue)
                mov   xwtmp, xwordvalue
                movzx eax, xwtmp
            ELSE               
                mov   ax, xwordvalue
                movzx eax, ax
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR xwfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    udword$ MACRO udwordvalue:req
        ;; unsigned dword
        LOCAL buffer, udtmp
        .data?
            udtmp  DWORD ?
            buffer BYTE  12 dup(?)
        IFNDEF udfmt    
        .data    
            udfmt  BYTE "%lu", 0
        ENDIF    
        .code
            IFE issize(udwordvalue, 4)
                echo ------------------------
                echo udword$ - requires DWORD
                echo ------------------------
                .ERR
            ENDIF    
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR udfmt, udwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sdword$ MACRO sdwordvalue:req
        ;; signed dword
        LOCAL buffer, sdtmp
        .data?
            sdtmp  SDWORD ?
            buffer BYTE   12 dup(?)
        IFNDEF sdfmt    
        .data    
            sdfmt BYTE "%ld", 0
        ENDIF    
        .code
            IFE issize(sdwordvalue, 4)
                echo -------------------------
                echo sdword$ - requires SDWORD
                echo -------------------------
                .ERR
            ENDIF        
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR sdfmt, sdwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xdword$ MACRO xdwordvalue:req
        ;; unsigned hex dword
        LOCAL buffer, xdtmp
        .data?
            xdtmp  DWORD ?
            buffer BYTE  12 dup(?)
        IFNDEF xdfmt    
        .data    
            xdfmt BYTE "%lX", 0
        ENDIF    
        .code
            IFE issize(xdwordvalue, 4)
                echo ------------------------
                echo xdword$ - requires DWORD
                echo ------------------------
                .ERR
            ENDIF        
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR xdfmt, xdwordvalue 
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    uqword$ MACRO uqwordvalue:req
        ;; unsigned qword
        LOCAL buffer
        .data?
            buffer BYTE 24 dup(?)
        IFNDEF uqwfmt    
        .data    
            uqwfmt BYTE "%I64u", 0
        ENDIF    
        .code
            IFE issize(uqwordvalue, 8)
                echo ------------------------
                echo uqword$ - requires QWORD
                echo ------------------------
                .ERR
            ENDIF        
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR uqwfmt, uqwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sqword$ MACRO sqwordvalue:req
        ;; signed qword
        LOCAL buffer
        .data?
            buffer BYTE 24 dup(?)
        IFNDEF sqwfmt    
        .data    
            sqwfmt BYTE "%I64d", 0
        ENDIF    
        .code
            IFE issize(sqwordvalue, 8)
                echo ------------------------
                echo sqword$ - requires QWORD
                echo ------------------------
                .ERR
            ENDIF            
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR sqwfmt, sqwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xqword$ MACRO xqwordvalue:req
        ;; unsigned hex qword
        LOCAL buffer
        .data?
            buffer BYTE 20 dup(?)
        IFNDEF xqwfmt    
        .data    
            xqwfmt BYTE "%I64X", 0
        ENDIF    
        .code
            IFE issize(xqwordvalue, 8)
                echo ------------------------
                echo xqword$ - requires QWORD
                echo ------------------------
                .ERR
            ENDIF            
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR xqwfmt, xqwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    real4$ MACRO r4value:req
        LOCAL buffer, r8value, r4tmp
        .data?
            r4tmp   REAL4 ?
            r8value REAL8 ?
            buffer  BYTE  48 dup(?)
        IFNDEF r8fmt    
        .data
            r8fmt   BYTE "%lf", 0
        ENDIF    
        .code
            IFE issize(r4value, 4)
                echo ------------------------
                echo real4$ - requires REAL4
                echo ------------------------
                .ERR
            ENDIF            
            IF isregister(r4value)
                push   r4value
                pop    r4tmp
                finit
                fld    r4tmp
            ELSE
                finit
                fld    r4value
            ENDIF    
            fstp   r8value
            fwait
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR r8fmt, r8value
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    real8$ MACRO r8value:req
        LOCAL buffer
        .data?
            buffer BYTE 320 dup(?)
        IFNDEF r8fmt    
        .data    
            r8fmt  BYTE "%lf", 0
        ENDIF    
        .code
            IFE issize(r8value, 8)
                echo ------------------------
                echo real8$ - requires REAL8
                echo ------------------------
                .ERR
            ENDIF            
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR r8fmt, r8value
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    real10$ MACRO r10value:req
        LOCAL buffer, r8value
        .data?
            r8value REAL8 ?
            buffer  BYTE  320 dup(?)
        IFNDEF r8fmt    
        .data    
            r8fmt   BYTE "%lf", 0
        ENDIF    
        .code
            IFE issize(r10value, 10)
                echo -------------------------
                echo real10$ - requires REAL10
                echo -------------------------
                .ERR
            ENDIF        
            fld    r10value
            fstp   r8value
            fwait
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR r8fmt, r8value
            EXITM <OFFSET buffer>
    ENDM

  ; ------------------------
  ; sscanf conversion macros
  ; ------------------------
    a2ub MACRO pStr:req
        LOCAL ub
        .data 
           ub BYTE 0    
        IFNDEF ubfmt   
        .const
            ubfmt BYTE "%hhu",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR ubfmt, ADDR ub
        EXITM <OFFSET ub>
    ENDM  
    ;---------------------------------------
    a2sb MACRO pStr:req
        LOCAL sb
        .data 
           sb SBYTE 0    
        IFNDEF sbfmt   
        .const
            sbfmt BYTE "%hhd",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR sbfmt, ADDR sb
        EXITM <OFFSET sb>
    ENDM  
    ;---------------------------------------
    h2ub MACRO pStr:req
        LOCAL ub
        .data 
           ub BYTE 0    
        IFNDEF xbfmt   
        .const
            xbfmt BYTE "%hhX",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR xbfmt, ADDR ub
        EXITM <OFFSET ub>
    ENDM  
    ;---------------------------------------
    a2uw MACRO pStr:req
        LOCAL uw
        .data 
           uw WORD 0    
        IFNDEF uwfmt   
        .const
            uwfmt BYTE "%hu",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR uwfmt, ADDR uw
        EXITM <OFFSET uw>
    ENDM   
    ;---------------------------------------
    a2sw MACRO pStr:req
        LOCAL sw
        .data 
           sw SWORD 0    
        IFNDEF swfmt   
        .const
            swfmt BYTE "%hd",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR swfmt, ADDR sw
        EXITM <OFFSET sw>
    ENDM   
    ;---------------------------------------
    h2uw MACRO pStr:req
        LOCAL uw
        .data 
           uw WORD 0    
        IFNDEF xwfmt   
        .const
            xwfmt BYTE "%hX",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR xwfmt, ADDR uw
        EXITM <OFFSET uw>
    ENDM   
    ;---------------------------------------
    a2ud MACRO pStr:req
        LOCAL ud
        .data 
            ud DWORD 0    
        IFNDEF udfmt   
        .const
            udfmt BYTE "%u",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR udfmt, ADDR ud
        EXITM <OFFSET ud>
    ENDM   
    ;---------------------------------------
    a2sd MACRO pStr:req
        LOCAL sd
        .data 
           sd SDWORD 0    
        IFNDEF sdfmt   
        .const
            sdfmt BYTE "%d",0
        ENDIF    
        .code
        invoke crt_sscanf, pStr, ADDR sdfmt, ADDR sd
        EXITM <OFFSET sd>
    ENDM   
    ;---------------------------------------
    h2ud MACRO pStr:req
        LOCAL ud
        .data 
            ud DWORD 0    
        IFNDEF xdfmt   
        .const
            xdfmt BYTE "%X",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR xdfmt, ADDR ud
        EXITM <OFFSET ud>    
    ENDM   
    ;---------------------------------------
    a2uq MACRO pStr:req
        LOCAL uq
        .data 
           align 8
           uq QWORD 0    
        IFNDEF uqfmt   
        .const
            uqfmt BYTE "%I64u",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR uqfmt, ADDR uq
        EXITM <OFFSET uq>
    ENDM   
    ;---------------------------------------
    a2sq MACRO pStr:req
        LOCAL sq
        .data 
           align 8
           sq QWORD ?    
        IFNDEF sqfmt   
        .const
            sqfmt BYTE "%I64d",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR sqfmt, ADDR sq
        EXITM <OFFSET sq>
    ENDM   
    ;-------------------------------------------
    h2uq MACRO pStr:req
        LOCAL uq
        .data 
           align 8
           uq QWORD 0    
        IFNDEF xqfmt   
        .const
            xqfmt BYTE "%I64X",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR xqfmt, ADDR uq
        EXITM <OFFSET uq>
    ENDM   
    ;---------------------------------------
    a2r4 MACRO pStr:req
        LOCAL r4
        .data
          r4 REAL4 0.0
        IFNDEF r4fmt   
        .const
            r4fmt BYTE "%f",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR r4fmt, ADDR r4 
        EXITM <OFFSET r4>
    ENDM   
    ;-------------------------------------------
    a2r8 MACRO pStr:req
        LOCAL r8
        .data
          align 8
          r8 REAL8 0.0
        IFNDEF r8fmt   
        .const
            r8fmt BYTE "%lf",0
        ENDIF
        .code
        invoke crt_sscanf, pStr, ADDR r8fmt, ADDR r8 
        EXITM <OFFSET r8>
    ENDM   
    ;--------------------------------------------
    a2r10 MACRO pStr:req
        LOCAL r8, r10
        .data
           align 16
           r10 REAL10 0.0
           r8  REAL8  0.0
        IFNDEF r8fmt
        .data
            r8fmt BYTE "%lf",0
        ENDIF
        .code
        invoke crt_sscanf, pStr, ADDR r8fmt, ADDR r8
        finit
        fld r8
        fstp r10
        EXITM <OFFSET r10>
    ENDM
    ;--------------------------------------------

; --------------------------------
; convert numbers to string output
; --------------------------------
; naming convention for wsprintf based macros.
;
; prefix
; ------
; u = unsigned
; s = signed
; x = hex
;
; data size
; ---------
; db = byte      8 bit
; dw = word     16 bit
; dd = dword    32 bit
; dq = qword    64 bit
;
; data output type
; ----------------
; trailing "$" = string output.
;
; EXAMPLE : udb$ = string output for unsigned byte value.
;
; -----------------------------------------------
; The following macros were designed by Greg Lyon.
; -----------------------------------------------
udb$ MACRO ubytevalue:req
    ;; unsigned byte
    LOCAL buffer, ubtmp
    .DATA?
        ubtmp  BYTE ?
        buffer BYTE 4 dup(?)
    IFNDEF ubfmt   
    .DATA   
        ubfmt  BYTE "%u", 0
    ENDIF   
    .CODE
        IFE issize(ubytevalue, 1)
            ECHO ----------------------
            ECHO udb$ - requires BYTE
            ECHO ----------------------
            .ERR
        ENDIF               
        mov buffer[0], 0
        IF isregister(ubytevalue)
            mov   ubtmp, ubytevalue
            movzx eax, ubtmp
        ELSE
            mov   al, ubytevalue
            movzx eax, al
        ENDIF   
        INVOKE wsprintf, ADDR buffer, ADDR ubfmt, eax
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
sdb$ MACRO sbytevalue:req
    ;; signed byte
    LOCAL buffer, sbtmp
    .DATA?
        sbtmp  SBYTE ?
        buffer BYTE  8 dup(?)
    IFNDEF sbfmt     
    .DATA   
        sbfmt  BYTE "%d", 0
    ENDIF   
    .CODE
        IFE issize(sbytevalue, 1)
            ECHO -----------------------
            ECHO sdb$ - requires SBYTE
            ECHO -----------------------
            .ERR
        ENDIF               
        mov    buffer[0], 0
        IF isregister(sbytevalue)
            mov   sbtmp, sbytevalue
            movsx eax, sbtmp
        ELSE     
            mov   al, sbytevalue
            movsx eax, al
        ENDIF   
        INVOKE wsprintf, ADDR buffer, ADDR sbfmt, eax
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
xdb$ MACRO xbytevalue:req
    ;; unsigned hex byte
    LOCAL buffer, xbtmp
    .DATA?
        xbtmp  BYTE ?
        buffer BYTE 4 dup(?)
    IFNDEF xbfmt   
    .DATA   
        xbfmt  BYTE "%X", 0
    ENDIF   
    .CODE
        IFE issize(xbytevalue, 1)
            ECHO ----------------------
            ECHO xdb$ - requires BYTE
            ECHO ----------------------
            .ERR
        ENDIF               
        mov buffer[0], 0
        IF isregister(xbytevalue)
            mov   xbtmp, xbytevalue
            movzx eax, xbtmp
        ELSE
            mov   al, xbytevalue
            movzx eax, al
        ENDIF   
        INVOKE wsprintf, ADDR buffer, ADDR xbfmt, eax
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
udw$ MACRO uwordvalue:req
    ;; unsigned word
    LOCAL buffer, uwtmp
    .DATA?
        uwtmp  WORD ?
        buffer BYTE 8 dup(?)
    IFNDEF uwfmt   
    .DATA   
        uwfmt  BYTE "%hu", 0
    ENDIF   
    .CODE
        IFE issize(uwordvalue, 2)
            ECHO ----------------------
            ECHO udw$ - requires WORD
            ECHO ----------------------
            .ERR
        ENDIF           
        mov   buffer[0], 0
        IF isregister(uwordvalue)
            mov   uwtmp, uwordvalue
            movzx eax, uwtmp
        ELSE       
            mov   ax, uwordvalue
            movzx eax, ax
        ENDIF   
        INVOKE wsprintf, ADDR buffer, ADDR uwfmt, eax
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
sdw$ MACRO swordvalue:req
    ;; signed word
    LOCAL buffer, swtmp
    .DATA?
        swtmp  SWORD ?
        buffer BYTE  8 dup(?)
    IFNDEF swfmt   
    .DATA   
        swfmt  BYTE "%hd", 0
    ENDIF   
    .CODE
        IFE issize(swordvalue, 2)
            ECHO -----------------------
            ECHO sdw$ - requires SWORD
            ECHO -----------------------
            .ERR
        ENDIF           
        mov   buffer[0], 0
        IF isregister(swordvalue)
            mov   swtmp, swordvalue
            movsx eax, swtmp
        ELSE   
            mov   ax, swordvalue
            movsx eax, ax
        ENDIF   
        INVOKE wsprintf, ADDR buffer, ADDR swfmt, eax
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
xdw$ MACRO xwordvalue:req
    ;; unsigned hex word
    LOCAL buffer, xwtmp
    .DATA?
        xwtmp  WORD ?
        buffer BYTE 8 dup(?)
    IFNDEF xwfmt   
    .DATA   
        xwfmt  BYTE "%hX", 0
    ENDIF   
    .CODE
        IFE issize(xwordvalue, 2)
            ECHO ----------------------
            ECHO xdw$ - requires WORD
            ECHO ----------------------
            .ERR
        ENDIF       
        mov   buffer[0], 0
        IF isregister(xwordvalue)
            mov   xwtmp, xwordvalue
            movzx eax, xwtmp
        ELSE               
            mov   ax, xwordvalue
            movzx eax, ax
        ENDIF   
        INVOKE wsprintf, ADDR buffer, ADDR xwfmt, eax
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
udd$ MACRO udwordvalue:req
    ;; unsigned dword
    LOCAL buffer
    .DATA?
        buffer BYTE  12 dup(?)
    IFNDEF udfmt   
    .DATA   
        udfmt  BYTE "%lu", 0
    ENDIF   
    .CODE
        IFE issize(udwordvalue, 4)
            ECHO ------------------------
            ECHO udd$ - requires DWORD
            ECHO ------------------------
            .ERR
        ENDIF   
        mov    buffer[0], 0
        INVOKE wsprintf, ADDR buffer, ADDR udfmt, udwordvalue
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
sdd$ MACRO sdwordvalue:req
    ;; signed dword
    LOCAL buffer
    .DATA?
         buffer BYTE   12 dup(?)
    IFNDEF sdfmt   
    .DATA   
        sdfmt BYTE "%ld", 0
    ENDIF   
    .CODE
        IFE issize(sdwordvalue, 4)
            ECHO -------------------------
            ECHO sdd$ - requires SDWORD
            ECHO -------------------------
            .ERR
        ENDIF       
        mov    buffer[0], 0
        INVOKE wsprintf, ADDR buffer, ADDR sdfmt, sdwordvalue
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
xdd$ MACRO xdwordvalue:req
    ;; unsigned hex dword
    LOCAL buffer
    .DATA?
        buffer BYTE  12 dup(?)
    IFNDEF xdfmt   
    .DATA   
        xdfmt BYTE "%lX", 0
    ENDIF   
    .CODE
        IFE issize(xdwordvalue, 4)
            ECHO ------------------------
            ECHO xdd$ - requires DWORD
            ECHO ------------------------
            .ERR
        ENDIF       
        mov    buffer[0], 0
        INVOKE wsprintf, ADDR buffer, ADDR xdfmt, xdwordvalue
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
udq$ MACRO uqwordvalue:req
    ;; unsigned qword
    LOCAL buffer
    .DATA?
        buffer BYTE 24 dup(?)
    IFNDEF uqwfmt   
    .DATA   
        uqwfmt BYTE "%I64u", 0
    ENDIF   
    .CODE
        IFE issize(uqwordvalue, 8)
            ECHO ------------------------
            ECHO udq$ - requires QWORD
            ECHO ------------------------
            .ERR
        ENDIF       
        mov    buffer[0], 0
        INVOKE wsprintf, ADDR buffer, ADDR uqwfmt, uqwordvalue
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
sdq$ MACRO sqwordvalue:req
    ;; signed qword
    LOCAL buffer
    .DATA?
        buffer BYTE 24 dup(?)
    IFNDEF sqwfmt   
    .DATA   
        sqwfmt BYTE "%I64d", 0
    ENDIF   
    .CODE
        IFE issize(sqwordvalue, 8)
            ECHO ------------------------
            ECHO sdq$ - requires QWORD
            ECHO ------------------------
            .ERR
        ENDIF           
        mov    buffer[0], 0
        INVOKE wsprintf, ADDR buffer, ADDR sqwfmt, sqwordvalue
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------
xdq$ MACRO xqwordvalue:req
    ;; unsigned hex qword
    LOCAL buffer
    .DATA?
        buffer BYTE 20 dup(?)
    IFNDEF xqwfmt   
    .DATA   
        xqwfmt BYTE "%I64X", 0
    ENDIF   
    .CODE
        IFE issize(xqwordvalue, 8)
            ECHO ------------------------
            ECHO xdq$ - requires QWORD
            ECHO ------------------------
            .ERR
        ENDIF           
        mov    buffer[0], 0
        INVOKE wsprintf, ADDR buffer, ADDR xqwfmt, xqwordvalue
        EXITM <OFFSET buffer>
ENDM
; ----------------------------------------------

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤

UC  TEXTEQU <UCCSTR>
UCC TEXTEQU <UCCSTR>

;/********************************************************************/
;/*                     fnx - macro procedure                        */
;/* This macro enhanced the INVOKE-directive:                        */
;/*   - It adds support for quoted ASCII or unicode strings.         */
;/*     The strings can be either enclosed by double quotes or by    */
;/*     single quotation marks.                                      */
;/*     The kind of created string (Unicode or ASCII) depends on the */
;/*     __UNICODE__ equate. If this equte is defined and has a       */
;/*     nonzero value, a unicode string is created. However, creation*/
;/*     of Unicode strings can be forced by using the 'L'-prefix:    */
;/*                 L"my string" or L'my string'                     */
;/*     ASCII strings can be forced by using the A-prefix:           */
;/*                 A"my string" or A'my string'                     */
;/*     MASM's reserved characters like exclamation marks, angel     */
;/*     brackets and single brackets [,...] can not be used.         */
;/*     (use fncx for escape sequences support)                      */
;/*   - ADDR-expressions can be shorten by using a ampersand '&':    */
;/*         fn MessageBoxW,0,&wsz[0],L'xyz',0                        */
;/*   - Pointers to DWORDs can be dereferenced, if they are leaded   */
;/*     by '*' (like dereferencing in c/c++):                        */
;/*                fnx MesageBox,0,*ppchar,...                       */
;/*   - a optional destination can be specified in front of the      */
;/*     function:                                                    */
;/*         fn dest=FncName,...                                      */
;/*                                                                  */
;/* Example:                                                         */
;/*     fnx MessageBoxW,0,L"my string",&wsz[0],0                     */
;/*     fnx hWnd = CreateWindowEx,...                                */
;/*                                                     qWord, 2011  */
;/********************************************************************/
fnx MACRO FncName:req,args:VARARG

    ;/* check if a optional destination is specified */
    fnex_flag = 0
    IF @InStr(1,<&FncName>,<=>)
        fnex_flag = 1
        fnex_dest SUBSTR <&FncName>,1,@InStr(1,<&FncName>,<=>)-1
        fnex_arg TEXTEQU <invoke >,@SubStr(<&FncName>,@InStr(1,<&FncName>,<=>)+1)
    ELSE    
        fnex_arg TEXTEQU <invoke FncName>
    ENDIF

    ;/* process argument list and append it to the invoke-call */
    fnex_arg CATSTR fnex_arg,repargs(0,&args)

    ;/* place the function call */
    fnex_arg

    ;/* if available, fill the specified destination */    
    IF fnex_flag EQ 1
        mov fnex_dest,eax
    ENDIF
endm


;/********************************************************************/
;/*                     fncx - macro procedure                       */
;/* This macro behave like the fnx-macros, except, that it adds      */
;/* support for escape sequences:                                    */
;/*     \\  ->  "\"                                                  */
;/*     \t  ->  tab                                                  */
;/*     \n  ->  new line (13,10)                                     */
;/*     \x  ->  "!"                                                  */
;/*     \a  ->  "("                                                  */
;/*     \b  ->  ")"                                                  */
;/*     \l  ->  "<"                                                  */
;/*     \r  ->  ">"                                                  */
;/*     \p  ->  "%"                                                  */
;/*     \A  ->  "&"                                                  */
;/*     \q  ->  double quote '"'                                     */
;/*     \0  ->  zero                                                 */
;/* Example:                                                         */
;/*     fncx MessageBox,0,"my string\n",&wsz[0],0                    */
;/*                                                     qWord, 2011  */
;/********************************************************************/
fncx MACRO FncName:req,args:VARARG

    ;/* check if a optional destination is specified */
    fnex_flag = 0
    IF @InStr(1,<&FncName>,<=>)
        fnex_flag = 1
        fnex_dest SUBSTR <&FncName>,1,@InStr(1,<&FncName>,<=>)-1
        fnex_arg TEXTEQU <invoke >,@SubStr(<&FncName>,@InStr(1,<&FncName>,<=>)+1)
    ELSE    
        fnex_arg TEXTEQU <invoke FncName>
    ENDIF

    ;/* process argument list and append it to the invoke-call */
    fnex_arg CATSTR fnex_arg,repargs(1,&args)

    ;/* place the function call */
    fnex_arg

    ;/* if available, fill the specified destination */    
    IF fnex_flag EQ 1
        mov fnex_dest,eax
    ENDIF
endm

;/********************************************************************/
;/*                     rvx - macro function                         */
;/* This macro is the function-version of the fnx-macro.             */
;/*                                                                  */
;/* Example:                                                         */
;/*      mov edi,rv(myFunction,L"my string",&wsz[0],...)             */
;/*      .break .if !rv(dest=myFunction,...)                         */
;/*                                                     qWord, 2011  */
;/********************************************************************/
rvx MACRO FncName:req,args:VARARG
    
    ;/* check if a optional destination is specified */
    rvex_flag = 0
    IF @InStr(1,<&FncName>,<=>)
        rvex_flag = 1
        rvex_dest SUBSTR <&FncName>,1,@InStr(1,<&FncName>,<=>)-1
        rvex_arg TEXTEQU <invoke >,@SubStr(<&FncName>,@InStr(1,<&FncName>,<=>)+1)
    ELSE    
        rvex_arg TEXTEQU <invoke FncName>
    ENDIF

    ;/* process argument list and append it to the invoke-call */
    rvex_arg CATSTR rvex_arg,repargs(0,&args)
    
    ;/* place the function call */
    rvex_arg
    
    ;/* if available, fill the specified destination */
    IF rvex_flag EQ 1
        mov rvex_dest,eax
    ENDIF
    EXITM <eax>
endm

;/********************************************************************/
;/*                     rvcx - macro function                        */
;/* This macro behave like the rvx-macros, except, that it adds      */
;/* support for escape sequences:                                    */
;/*     \\  ->  "\"                                                  */
;/*     \t  ->  tab                                                  */
;/*     \n  ->  new line (13,10)                                     */
;/*     \x  ->  "!"                                                  */
;/*     \a  ->  "("                                                  */
;/*     \b  ->  ")"                                                  */
;/*     \l  ->  "<"                                                  */
;/*     \r  ->  ">"                                                  */
;/*     \p  ->  "%"                                                  */
;/*     \A  ->  "&"                                                  */
;/*     \q  ->  double quote '"'                                     */
;/*     \0  ->  zero                                                 */
;/* Example:                                                         */
;/*     mov edi,rv(myFunction,L"my string\x\n",&wsz[0],...)          */
;/*                                                     qWord, 2011  */
;/********************************************************************/
rvcx MACRO FncName:req,args:VARARG
    
    ;/* check if a optional destination is specified */
    rvex_flag = 0
    IF @InStr(1,<&FncName>,<=>)
        rvex_flag = 1
        rvex_dest SUBSTR <&FncName>,1,@InStr(1,<&FncName>,<=>)-1
        rvex_arg TEXTEQU <invoke >,@SubStr(<&FncName>,@InStr(1,<&FncName>,<=>)+1)
    ELSE    
        rvex_arg TEXTEQU <invoke FncName>
    ENDIF

    ;/* process argument list and append it to the invoke-call */
    rvex_arg CATSTR rvex_arg,repargs(1,&args)
    
    ;/* place the function call */
    rvex_arg
    
    ;/* if available, fill the specified destination */
    IF rvex_flag EQ 1
        mov rvex_dest,eax
    ENDIF
    EXITM <eax>
endm

;/******************************************************************/ 
;/*                 repargs , macro function                       */
;/* Parse the arguments list 'args' and replace:                   */
;/*     - String literals by the corresponding OFFSET-expression   */
;/*       after creating an anonym string in the .data-section     */
;/*     - leading ampersands (&) by the ADDR operator              */
;/*     - dereferencing of pointers, if the leading char. is a '*' */
;/* All other arguments are left untouched.                        */
;/*                                                                */
;/* Parameter:   cstr: indicates whether to support escape         */
;/*                    sequences in string literals or not {0,1}   */
;/*              args: arguments to parse                          */
;/* Details:                                                       */
;/*     This macro creates, according to the __UNICODE__-equate,   */
;/*     either ASCII or Unicode strings. However, Unicode strings  */
;/*     can be forced by using the 'L'-Prefix:                     */
;/*       L"my unicode string"  or L'my "quoted" string'           */
;/*     ASCII string can be forced by the 'A'-prefix:              */
;/*       A"my ASCII string"  or A'xyz 1234 '                      */
;/*     Furthermore, ampersands are replaced by <ADDR >, if they   */
;/*     are the first character of the argument:                   */
;/*        ..., &sz[0],...    ->   ..., ADDR sz[0],...             */
;/*     If the leading char. is a <*>, the argument is             */
;/*     interpreted as a pointer to a DWORD, which is loaded:      */
;/*         mov pchar, chr$("xyz")                                 */
;/*         lea eax,pchar                                          */
;/*         mov ppchar,eax                                         */
;/*         fn MessageBox,0,*ppchar,...                            */
;/*                                                                */
;/* Return:                                                        */
;/*     The processed argument list. If a nonempty list is passed  */
;/*     to the macro, the returned list is always leaded           */
;/*     by a comma:                                                */
;/*         <arg1,arg2,...> -> <,newArg1,newArg2,...>              */
;/*     The number of arguments in list is stored in               */
;/*     the equate repargs_cntr.                                   */
;/*                                                                */
;/* Remarks:                                                       */
;/*     This macro is designed to process arguments lists for      */
;/*     the INVOKE-directive.                                      */
;/*     The macro assumes to be called from the .code-section      */
;/*                                                                */
;/* Example:                                                       */
;/*     invk_txt TEXTEQU <invoke FncName>                          */
;/*     invk_txt CATSTR invk_txt,repargs(ArgumentList)             */
;/*     invk_txt                                                   */
;/*                                                                */
;/*                                                  qWord, 2011   */
;/******************************************************************/ 
repargs MACRO cstr:=<0>,args:VARARG
    
    ;/* initialize global counter which */
    ;/* is used for label-creation.      */
    IFNDEF repargs_glb_cntr
        repargs_glb_cntr = 0
    ENDIF

    repargs_unicode = 0
    IFDEF __UNICODE__
        IF __UNICODE__
            repargs_unicode = 1
        ENDIF
    ENDIF
    
    ;/* count arguments (needed for dereferencing operator) */
    repargs_nargs = 0
    FOR arg,<&args>
        repargs_nargs = repargs_nargs + 1
    ENDM
    repargs_eax_saved = 0

    repargs_cntr = 0
    repargs_args TEXTEQU <>
    FOR arg,<&args>
        repargs_txt  TEXTEQU <&arg>
       
        ;/* analyze current argument */
        repargs_pos1 INSTR 1,<&arg>,<">
        repargs_pos2 INSTR 1,<&arg>,<'>
        repargs_pos3 INSTR 1,<&arg>,<L">
        repargs_pos4 INSTR 1,<&arg>,<L'>
        repargs_pos5 INSTR 1,<&arg>,<A">
        repargs_pos6 INSTR 1,<&arg>,<A'>
        repargs_pos7 INSTR 1,<&arg>,<!&>
        repargs_pos8 INSTR 1,<&arg>,<*>

        IF repargs_pos1 EQ 1 OR repargs_pos2 EQ 1
            repargs_str_type = 1                       ; ASCII
            IF repargs_unicode
                repargs_str_type = 2                   ; Unicode
            ENDIF
        ELSEIF repargs_pos3 EQ 1 OR repargs_pos4 EQ 1
            repargs_str_type = 2                       ; Unicode
            repargs_txt SUBSTR repargs_txt,2           ; remove prefix
        ELSEIF repargs_pos5 EQ 1 OR repargs_pos6 EQ 1
            repargs_str_type = 1                       ; ASCII
            repargs_txt SUBSTR repargs_txt,2           ; remove prefix
        ELSE
            repargs_str_type = 0                       ; no string
        ENDIF
        
        IF repargs_str_type EQ 1
            ;/ create ASCII string */
            .data
                IF @SizeStr(<%repargs_txt>) GT 2
                    IFE cstr
                        @CatStr(<$$_szlbl_>,%repargs_glb_cntr) db repargs_txt,0
                    ELSE
                        ?cstr? @CatStr(<$$_szlbl_>,%repargs_glb_cntr),<%repargs_txt>,0
                    ENDIF
                ELSE
                    @CatStr(<$$_szlbl_>,%repargs_glb_cntr) db 0
                ENDIF               
            .code
            repargs_args TEXTEQU repargs_args,<,OFFSET $$_szlbl_>,%repargs_glb_cntr
            repargs_glb_cntr = repargs_glb_cntr + 1
        ELSEIF repargs_str_type EQ 2
            ;/* create Unicode string */
            .data
                IF @SizeStr(<%repargs_txt>) GT 2
                    IFE cstr
                        UCSTR @CatStr(<$$_wszlbl_>,%repargs_glb_cntr),<%repargs_txt>,0
                    ELSE
                        UCCSTR @CatStr(<$$_wszlbl_>,%repargs_glb_cntr),<%repargs_txt>,0
                    ENDIF
                ELSE
                    @CatStr(<$$_wszlbl_>,%repargs_glb_cntr) dw 0
                ENDIF
            .code
            repargs_args TEXTEQU repargs_args,<,OFFSET $$_wszlbl_>,%repargs_glb_cntr
            repargs_glb_cntr = repargs_glb_cntr + 1
        ELSEIF repargs_pos7 EQ 1
            ;/* replace '&' with <ADDR > and append argument to list */
            repargs_args TEXTEQU repargs_args,<,>,<ADDR >,@SubStr(%repargs_txt,2,)
        ELSEIF repargs_pos8 EQ 1
            ;/* dereference operator '*' */

            repargs_txt SUBSTR repargs_txt,2  ; remove <*>

            ;/* register ? */
            IF ((OPATTR repargs_txt) AND 10000y) NE 0
                repargs_args TEXTEQU repargs_args,<,>,<DWORD ptr [>,repargs_txt,<]>
            ELSE
                IFE repargs_eax_saved
                    mov DWORD ptr [esp-4],eax
                    repargs_eax_saved = 1
                ENDIF
                mov eax,repargs_txt
                mov eax,[eax]
                mov DWORD ptr [esp-2*repargs_nargs*4+repargs_cntr*4],eax
                repargs_args TEXTEQU repargs_args,<,>,<DWORD ptr [esp->,%(repargs_nargs*4+4),<]>
            ENDIF
        ELSE
            ;/* record unprocessed argument */
            repargs_args TEXTEQU repargs_args,<,>,repargs_txt
        ENDIF
        repargs_cntr = repargs_cntr + 1
    ENDM
    IF repargs_eax_saved
        mov eax,DWORD ptr [esp-4]
    ENDIF
    EXITM repargs_args
endm


;/*****************************************************************/
;/*             UCSTR - macro procedure                           */
;/* This macro creates a Unicode string in the current segment    */
;/* Parameters:                                                   */
;/*    lbl:    [optional] name of string                          */
;/*    args:   one ore more string literals, either enclosed by   */
;/*            single quotation marks or by double quotes.        */
;/*            Constants can also be used, blank arguments        */
;/*            force an error. The maximal number of characters   */
;/*            is something about 240.                            */
;/*                                                               */
;/* Remarks:   A termination zero must add by user!               */
;/*            Named strings can be used with the SIZEOF and      */
;/*            LENGTHOF operator. This macro wont work with       */
;/*            angle brackets and exclemation marks.              */
;/* Example:                                                      */
;/*          UCSTR myStr, "my string",13,10,'"quoted"',0          */
;/*                                                  qWord, 2011  */
;/*****************************************************************/
UCSTR MACRO lbl,args:VARARG
    
    ;/* initialize counter used for label creation */
    IFNDEF ucstr_lbl_cntr
        ucstr_lbl_cntr = 0
    ENDIF
    
    ;/* if required, create a label */
    IFB <&lbl>
        ucstr_lbl TEXTEQU <$$_WSTR_>,%ucstr_lbl_cntr
        ucstr_lbl_cntr = ucstr_lbl_cntr + 1
    ELSE
        ucstr_lbl TEXTEQU <&lbl>
    ENDIF

    ucstr_size = 0
    ucstr_flg = 0  ; 0 => invalid argument
                   ; 1 => double quotes are used
                   ; 2 => single quotation marks are used
                   ; 3 => constant 
    ucstr_iarg = 1

    ;/* The following loop count the number of required WCHAR's */
    FOR _arg,<&args>
        ;/* loop through all characters */
        ucstr_flg = 0
        FORC char,<&_arg>
            IF ucstr_flg NE 0
                ucstr_pos INSTR 1,<"'>,<&char>
                ;/* end of quoted string reached? */
                IF ucstr_pos EQ ucstr_flg
                    EXITM
                ENDIF
                ucstr_size = ucstr_size + 1
            ELSE
                ;/* This part is only one time executet for each argument _arg. */
                ;/* It determine wheter a string litreal, a numeric constant or */
                ;/* an invalid arguemten is present.                            */
                ucstr_flg INSTR 1,<"'>,<&char>
                IFE ucstr_flg
                    ;/* constant value ? */
                    IF (OPATTR _arg) AND 100y
                        ucstr_flg = 3
                    ENDIF
                    EXITM
                ENDIF
            ENDIF
        ENDM
        IF ucstr_flg EQ 3
            ;/* numeric constant */
            ucstr_size = ucstr_size + 1
        ELSEIFE ucstr_flg
            ;/* invalid argument detected -> exit */
            EXITM
        ENDIF
        ucstr_iarg = ucstr_iarg + 1     
    ENDM
    IFE ucstr_flg
    %   .err <invalid string specifier : argument : @CatStr(%ucstr_iarg)>
        EXITM
    ENDIF
    
    ;/* allocate string in current segment */
    align 2
    ucstr_lbl WORD ucstr_size dup (?)
    org $-ucstr_size*2
    
    ;/* This loop is nearly identically to the one above, excpet that char. are emitted */
    FOR _arg,<&args>
        ucstr_flg = 0
        FORC char,<&_arg>
            IF ucstr_flg NE 0
                ucstr_pos INSTR 1,<"'>,<&char>
                IF ucstr_pos EQ ucstr_flg
                    EXITM
                ELSE
                    ucstr_char CATSTR <dw >,ucstr_quote,<&char>,ucstr_quote
                    ucstr_char
                ENDIF
            ELSE
                ucstr_flg INSTR 1,<"'>,<&char>
                IFE ucstr_flg
                    IF (OPATTR _arg) AND 100y
                        ucstr_flg = 3
                    ENDIF
                    EXITM
                ENDIF
                ucstr_quote TEXTEQU <&char>
            ENDIF
        ENDM
        IF ucstr_flg EQ 3
            dw _arg
        ELSEIFE ucstr_flg
            EXITM
        ENDIF
        ucstr_iarg = ucstr_iarg + 1     
    ENDM

endm

;/***************************************************/
;/*               uc$ , macro function              */
;/* This macro is the function-version of UCSTR.    */
;/* In contrast to UCSTR, the created string is     */
;/* zero terminated. The macro assumes to be called */
;/* from the .code-section and places the string    */
;/* in the .data-section.                           */
;/* Example:                                        */
;/*      mov esi,uc$("my string",13,10,'xxyz')      */
;/*                                    qWord, 2011  */
;/***************************************************/
uc$ MACRO args:VARARG
    .data
        UCSTR ,args,0
    .code
    ucsz_retval TEXTEQU <OFFSET >,ucstr_lbl
    EXITM ucsz_retval
endm

;/*****************************************************************/
;/*             UCCSTR - macro procedure                          */
;/* This macro creates a Unicode string in the current segment    */
;/* This macro is identically to the UCSTR-macro, except, that it */
;/* adds support for some escape sequences:                       */
;/*     \\  ->  "\"                                               */
;/*     \t  ->  tab                                               */
;/*     \n  ->  new line (13,10)                                  */
;/*     \x  ->  "!"                                               */
;/*     \a  ->  "("                                               */
;/*     \b  ->  ")"                                               */
;/*     \l  ->  "<"                                               */
;/*     \r  ->  ">"                                               */
;/*     \p  ->  "%"                                               */
;/*     \A  ->  "&"                                               */
;/*     \q  ->  double quote '"'                                  */
;/*     \0  ->  zero-word                                         */
;/*                                                               */
;/* Example:                                                      */
;/*       UCCSTR myStr, "line 1\nline2\nI'm here\x",0             */
;/*                                                  qWord, 2011  */
;/*****************************************************************/
UCCSTR MACRO lbl,args:VARARG

    IFNDEF uccstr_lbl_cntr
        uccstr_lbl_cntr = 0
    ENDIF
    IFB <&lbl>
        uccstr_lbl TEXTEQU <anonym_WSTR_>,%uccstr_lbl_cntr
        uccstr_lbl_cntr = uccstr_lbl_cntr + 1
    ELSE
        uccstr_lbl TEXTEQU <&lbl>
    ENDIF

    uccstr_size = 0
    uccstr_flg = 0
    uccstr_iarg = 1
    uccstr_esc = 0
    FOR _arg,<args>
        uccstr_flg = 0
        FORC char,<&_arg>
            IF uccstr_flg NE 0
                uccstr_pos INSTR 1,<"'\>,<&char>
                IF uccstr_pos EQ uccstr_flg
                    EXITM
                ELSEIF uccstr_pos EQ 3 AND uccstr_esc EQ 0
                uccstr_esc = 1
                ELSE
                    IF uccstr_esc
                        uccstr_pos INSTR 1,<\0ablrxqtpAn>,<&char>
                        
                        IFE uccstr_pos
                            uccstr_flg=0
                            EXITM
                        ENDIF
                        uccstr_size = uccstr_size + uccstr_pos/12
                        uccstr_esc = 0
                    ENDIF
                    uccstr_size = uccstr_size + 1
                ENDIF
            ELSE
                uccstr_flg INSTR 1,<"'>,<&char>
                IFE uccstr_flg
                    IF (OPATTR _arg) AND 100y
                        uccstr_flg = 3
                    ENDIF
                    EXITM
                ENDIF
            ENDIF
        ENDM
        IF uccstr_flg EQ 0 OR uccstr_esc NE 0
            EXITM
        ELSEIF uccstr_flg EQ 3
            uccstr_size = uccstr_size + 1
        ENDIF       
        uccstr_iarg = uccstr_iarg + 1
    ENDM
    IF uccstr_flg EQ 0 OR uccstr_esc NE 0
        IF uccstr_esc
        %   .err <invalid escape sequence : argument : @CatStr(%uccstr_iarg)>
        ELSE
        %   .err <invalid string specifier : argument : @CatStr(%uccstr_iarg)>
        ENDIF
        EXITM
    ENDIF
    
    align 2
    uccstr_lbl WORD uccstr_size dup (?)
    org $-uccstr_size*2
    
    uccstr_esc = 0
    FOR _arg,<&args>
        uccstr_flg = 0
        FORC char,<&_arg>
            IF uccstr_flg NE 0
                uccstr_pos INSTR 1,<"'\>,<&char>
                IF uccstr_pos EQ uccstr_flg
                    EXITM
                ELSEIF uccstr_pos EQ 3 AND uccstr_esc EQ 0
                    uccstr_esc = 1
                ELSE
                    IFE uccstr_esc
                        uccstr_char CATSTR <dw >,uccstr_quote,<&char>,uccstr_quote
                        uccstr_char
                    ELSE
                        uccstr_pos INSTR 1,<\0ablrxqtpAn>,<&char>
                        IFE uccstr_pos
                            uccstr_flg=0
                            EXITM
                        ENDIF
                        uccstr_char SUBSTR <  5ch00h28h29h3ch3eh21h22h09h25h26h0ah,0dh>,uccstr_pos*3,3+4*(uccstr_pos/12)
                        uccstr_esc = 0
                        dw uccstr_char
                    ENDIF
                ENDIF
            ELSE
                uccstr_flg INSTR 1,<"'>,<&char>
                IFE uccstr_flg
                    IF (OPATTR _arg) AND 100y
                        uccstr_flg = 3
                    ENDIF
                    EXITM
                ENDIF
                uccstr_quote TEXTEQU <&char>
            ENDIF
        ENDM
        IF uccstr_flg EQ 3
            dw _arg
        ENDIF       
    ENDM

endm

;/* internal: ASCII-counterpart of UCCSTR */
?cstr? MACRO lbl,args:VARARG

    IFNDEF ?cstr?_lbl_cntr
        ?cstr?_lbl_cntr = 0
    ENDIF
    IFB <&lbl>
        ?cstr?_lbl TEXTEQU <anonym_WSTR_>,%?cstr?_lbl_cntr
        ?cstr?_lbl_cntr = ?cstr?_lbl_cntr + 1
    ELSE
        ?cstr?_lbl TEXTEQU <&lbl>
    ENDIF

    ?cstr?_size = 0
    ?cstr?_flg = 0
    ?cstr?_iarg = 1
    ?cstr?_esc = 0
    FOR _arg,<args>
        ?cstr?_flg = 0
        FORC char,<&_arg>
            IF ?cstr?_flg NE 0
                ?cstr?_pos INSTR 1,<"'\>,<&char>
                IF ?cstr?_pos EQ ?cstr?_flg
                    EXITM
                ELSEIF ?cstr?_pos EQ 3 AND ?cstr?_esc EQ 0
                ?cstr?_esc = 1
                ELSE
                    IF ?cstr?_esc
                        ?cstr?_pos INSTR 1,<\0ablrxqtpAn>,<&char>
                        
                        IFE ?cstr?_pos
                            ?cstr?_flg=0
                            EXITM
                        ENDIF
                        ?cstr?_size = ?cstr?_size + ?cstr?_pos/12
                        ?cstr?_esc = 0
                    ENDIF
                    ?cstr?_size = ?cstr?_size + 1
                ENDIF
            ELSE
                ?cstr?_flg INSTR 1,<"'>,<&char>
                IFE ?cstr?_flg
                    IF (OPATTR _arg) AND 100y
                        ?cstr?_flg = 3
                    ENDIF
                    EXITM
                ENDIF
            ENDIF
        ENDM
        IF ?cstr?_flg EQ 0 OR ?cstr?_esc NE 0
            EXITM
        ELSEIF ?cstr?_flg EQ 3
            ?cstr?_size = ?cstr?_size + 1
        ENDIF       
        ?cstr?_iarg = ?cstr?_iarg + 1
    ENDM
    IF ?cstr?_flg EQ 0 OR ?cstr?_esc NE 0
        IF ?cstr?_esc
        %   .err <invalid escape sequence : argument : @CatStr(%?cstr?_iarg)>
        ELSE
        %   .err <invalid string specifier : argument : @CatStr(%?cstr?_iarg)>
        ENDIF
        EXITM
    ENDIF
    
    ?cstr?_lbl BYTE ?cstr?_size dup (?)
    org $-?cstr?_size
    
    ?cstr?_esc = 0
    FOR _arg,<&args>
        ?cstr?_flg = 0
        FORC char,<&_arg>
            IF ?cstr?_flg NE 0
                ?cstr?_pos INSTR 1,<"'\>,<&char>
                IF ?cstr?_pos EQ ?cstr?_flg
                    EXITM
                ELSEIF ?cstr?_pos EQ 3 AND ?cstr?_esc EQ 0
                    ?cstr?_esc = 1
                ELSE
                    IFE ?cstr?_esc
                        ?cstr?_char CATSTR <db >,?cstr?_quote,<&char>,?cstr?_quote
                        ?cstr?_char
                    ELSE
                        ?cstr?_pos INSTR 1,<\0ablrxqtpAn>,<&char>
                        IFE ?cstr?_pos
                            ?cstr?_flg=0
                            EXITM
                        ENDIF
                        ?cstr?_char SUBSTR <  5ch00h28h29h3ch3eh21h22h09h25h26h0ah,0dh>,?cstr?_pos*3,3+4*(?cstr?_pos/12)
                        ?cstr?_esc = 0
                        db ?cstr?_char
                    ENDIF
                ENDIF
            ELSE
                ?cstr?_flg INSTR 1,<"'>,<&char>
                IFE ?cstr?_flg
                    IF (OPATTR _arg) AND 100y
                        ?cstr?_flg = 3
                    ENDIF
                    EXITM
                ENDIF
                ?cstr?_quote TEXTEQU <&char>
            ENDIF
        ENDM
        IF ?cstr?_flg EQ 3
            db _arg
        ENDIF       
    ENDM
endm

;/***************************************************/
;/*               ucc$ , macro function             */
;/* This macro is the function-version of UCCSTR.   */
;/* In contrast to UCCSTR, the created string is    */
;/* zero terminated. The macro assumes to be called */
;/* from the .code-section and places the string    */
;/* in the .data-section.                           */
;/*     mov esi,ucc$("\lHello World\r\n:-\b")       */
;/*                                    qWord, 2011  */
;/***************************************************/
ucc$ MACRO args:VARARG
    .data
        UCCSTR ,args,0
    .code
    uccsz_retval TEXTEQU <OFFSET >,uccstr_lbl
    EXITM uccsz_retval
ENDM

; ¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤
