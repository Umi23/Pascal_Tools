{********************************************************************

 source file      : UniW32.pas
 typ              : Pascal Unit
 creation date    : 2015-08-01
 compiler version : FPC 2.6.4 / 3.0.4
 system           : Windows 7 64-bit
 last revision    : 2020-12-19 with FPC 3.2
 header           : Unicode convert functions in
                    Assembler for 32-bit working systems
                    with Intel or AMD CPU (CPU >= 80486)

 Copyright (c)    : 2019 - 2021 Klaus Stöhr
 e-mail  k.stoehr@gmx.de

 This program is free software; you can redistribute
 it and/or modify it under the terms of the GNU
 Lesser General Public License as published by the
 Free Software Foundation; either version 3 of the
 License, or (at your option) any later version.

 As a special exception, the copyright holders of this
 library give you permission to link this library with
 independent modules to produce an executable,
 regardless of the license terms of these independent
 modules, and to copy and distribute the resulting
 executable under terms of your choice, provided that
 you also meet, for each linked independent module,
 the terms and conditions of the license of that module.
 An independent module is a module which is not
 derived from or based on this library.

 This program is distributed in the hope that it will
 be useful, but WITHOUT ANY WARRANTY; without even the
 implied warranty of MERCHANTABILITY or FITNESS FOR A
 PARTICULAR PURPOSE. See the GNU Lesser General Public
 License for more details.
 You should have received a copy of the GNU Library
 General Public License along with this library; if not,
 write to the Free Software Foundation,Inc., 59
 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

********************************************************************}
unit UniW32;
{$MODE objfpc}{$H+}
{$ASMMODE INTEL}
{$CODEPAGE UTF8}
{$OPTIMIZATION OFF}   // no compiler optimization; assembler is optimized

{REMARK:
  Minimum need on Intel >= 80486 processor
  The unit only tested on the official FPU releases (2.6.4 and >= 3.0
  or higher).
  All functions start with a 'fn' on your name. This is for difference
  with homonomous names of system functions.

  All routines convert the result without BOM (byte order mark). When
  you needed it, you must insert the BOM with the insert routine from freepascal.
  For description of the routines read this in implementations part.
}

interface

{$IFDEF CPU386}

{ byte order tyLE = low order (Intel) processor tyBE = high order}
type
  TByteOrder = (tyLE,tyBE);

(*---------------------------UTF8------------------------------------------- *)
{$IFDEF FPC_HAS_CPSTRING}
function fnUTF8Length(const sText :Rawbytestring):Longint;register;
function fnUTF8ToUTF16(const sText :Rawbytestring;
                      OutByteOrder :TByteorder = tyLE):Unicodestring;register;
function fnUTF8ToUTF32(const sText :Rawbytestring):UCS4string;register;
{$ELSE}
function fnUTF8Length(const sText :string):Longint;register;
function fnUTF8ToUTF16(const sText :string;
                      OutByteOrder :TByteorder = tyLE):Unicodestring;register;
function fnUTF8ToUTF32(const sText :string):UCS4String;register;
{$ENDIF}

(*---------------------------UTF16------------------------------------------ *)
function fnUTF16ToUTF32(const sText :UnicodeString;
                      InByteOrder :TByteOrder = tyLE):UCS4String;register;
{$IFDEF FPC_HAS_CPSTRING}
function fnUTF16ToUTF8(const sText :Unicodestring;
                     InByteOrder :TByteOrder = tyLE):Rawbytestring;register;
{$ELSE}
function fnUTF16ToUTF8(const sText :Unicodestring;
              InByteOrder :TByteOrder = tyLE):string;register;
{$ENDIF}
(*---------------------------UTF32----------------------------------------- *)
function fnUTF32ToUTF16(constref sText :UCS4String;
                    OutByteOrder :TByteOrder = tyLE):UnicodeString;register;
{$IFDEF FPC_HAS_CPSTRING}
function fnUTF32ToUTF8(constref sText :UCS4String):Rawbytestring;register;
{$ELSE}
function fnUTF32ToUTF8(constref sText :UCS4String):string;register;
{$ENDIF}
{$ENDIF CPU386}

implementation

{$IFDEF CPU386}

{Remark: Why byte order?
         Its posible that we receive a file with other coding sequence
         (tyBE) and so that we need a convert for use on windows. Also
         could be the other fall we need for data exchange with other
         operating system a convert. (tyLE -> tyBE)
         UTF32 will only use on computer internal and not common for change
         data with other operating systems. Intel and AMD processord use
         tyLE and so we need no other byte order.

         I have only taken standard commands for all intel procesors from
         80486 and higher. Many assembler sequence on follow code is for
         speed.
         One BOM (byte order mark) on UTF8 encoded string is not recommended
         and we ignoring on convert.
         See Unicode Standard 11 (or higher) Part 3.10 unicode convert schemas!

         Follow the UNICODE standard, ill codepoints on source are changed
         to U+FFFD on result string.

         For UTF8    -> $EFBFBD
             UTF16LE -> $FDFF
             UTF16BE -> $FFFD
             UTF32LE -> $FDFF0000
             UTF32BE -> $0000FFFD

         BOM: UTF8    = $EFBBBF
              UTF16LE = $FFFE;
              UTF16BE = $FEFF;
              UTF32LE = $FFFE0000;
              UTF32BE = $0000FEFF;
}

(*-------------------Assembler----------------------------------------*)

{ The result of the function is the number of UTF8 chars on sText. Ill
  code points will count en order the unicode standard (see Unicode 11.0 or
   higher, part 3.9 page 129 table 3.8,3.9 and 3.10)
}

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF8Length(const sText :Rawbytestring):Longint;register;
             assembler;nostackframe;
{$ELSE}
function fnUTF8Length(const sText :string):Longint;register;
             assembler;nostackframe;
{$ENDIF}

{ Input:
     eax = addres sText

   Output:
     eax = count of UTF8 chars in sText

   use the registers:
     eax = for tests
     edx = byte length from sText,
     ecx = counter of UTF8Char
     esi = source pointer
     ebx = for test

   Remark: The load of 4 byte for test BOM is ok, a string have a Nul byte
           at the end.
}

asm
  test eax,eax;              // test addres
  jz   @stop;
  push ebx;
  push esi;
  mov  esi,eax;              // Adress pointer
  xor  eax,eax;              // clear return
  xor  ecx,ecx;              // Counter
 {$IFDEF FPC_HAS_CPSTRING}
  (* description: test it's a real UTF8 string *)
  movzx edx,word ptr[esi-12]; // CodePage Info
  cmp  edx,65001;            // if UTF8string?
  jne  @ende;
 {$ENDIF}
  mov  edx,dword ptr[esi-4]; // string length
  cmp  edx,0;
  jle  @ende;
  jo   @ende;                // we have SIGNED Values!

  cmp  edx,3;                // if BOM possibility?
  jl   @Load;                // no, when < 3
  mov  eax,dword ptr[esi];   // we receive no error, we have a Nul byte at end!
  and  eax,$00FFFFFF;        // only 3 byte test
  cmp  eax,$00BFBBEF;        // UTF8 BOM?
  jne  @load;
  add  ecx,1;                // count BOM
  add  esi,3;                // yes, correct the source pointer
  sub  edx,3;                // and length of string
  jle  @ende;

align 16;
 @load:
  mov  al,byte ptr[esi];     // load start byte for test
  cmp  al,$80;               // ASCII code?
  jb   @start1;              // yes, 1 Byte
  cmp  al,$C2;               // value $80...$C1 can not be start sequenz
  jb   @foultcoding;
  cmp  al,$DF;               // 2 byte
  jbe  @start2;
  cmp  al,$EF;               // 3 byte
  jbe  @start3;
  cmp  al,$F4;               // 4 byte
  jbe  @start4;
  ja   @foultcoding;         // error coding

align 16
 @start1:                   // start byte sequence
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jg   @load;
  jle  @Ende;

align 16;
 @Start2:                    // start 2 byte sequence
  cmp  edx,2;
  jl   @foultcoding;
  movzx eax,word ptr[esi];
  bswap eax;                 // for better test
  mov  ebx,eax;
  and  ebx,$E0C00000;        // test of conform
  cmp  ebx,$C0800000;        // 110xxxxx 10xxxxxx
  jne  @foult2;
  cmp  eax,$C2800000;        // min value for 2 byte sequence
  jb   @foult2;
  cmp  eax,$DFBF0000;        // max value for 2 byte sequence
  ja   @foult2;
  add  esi,2;
  add  ecx,1;
  sub  edx,2;
  jg   @Load;
  jle  @Ende;

align 16;
 @foult2:
  bswap eax;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  ah,$80;              // folge byte start byte?
  jb   @Load;
  cmp  ah,$C2;
  jae  @Load;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start3:                   // start 3 byte sequence
  cmp  edx,3;
  jl   @foult30;
  mov  eax,dword ptr[esi];
  and  eax,$00FFFFFF;
  bswap eax;
  mov  ebx,eax;
  and  ebx,$F0C0C000;        // test for conform
  cmp  ebx,$E0808000;        // 1110xxxx 10xxxxxx 10xxxxxx
  jne  @foult3               // not conform -> error
  cmp  eax,$E0A08000;        // minimal 3 byte value
  jb   @foult3;
  cmp  eax,$EFBFBF00;        // maximal 3 byte value
  ja   @foult3;
  cmp  eax,$ED9FBF00;
  ja   @test31;
  add  esi,3;
  add  ecx,1;
  sub  edx,3;
  jg   @Load;
  jle  @Ende;

align 16;
 @test31:                     // special test
  cmp eax,$EE808000;
  jb  @foult3;               // when < surrogate range
  add esi,3;
  add ecx,1;
  sub edx,3;                 // only 3 bytes
  jg  @load;
  jle @ende;

align 16;
 @foult30:             // string length < 3 byte
  cmp edx,2;
  je  @error2;
  add ecx,1;
  sub edx,1;
  jle @ende;
 @error2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult3:
  mov  ebx,2;           // count of folge tests
  bswap eax;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$E0;          // test for special start byte
  je   @E0;
  cmp  al,$ED;          // dito
  je   @ED;
align 16;
 @1:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @1;
  add  ecx,1;
  jmp  @1;
 @E0:                   // special test
  cmp  ah,$A0;
  jae  @1;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
 @ED:                  // dito
  cmp  ah,$9F;
  jbe  @1;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @Start4:                   // start  4 byte sequence
  cmp  edx,4
  jl   @foult40;
  mov  eax,dword ptr [esi];
  bswap eax;
  mov  ebx,eax;
  and  ebx,$F8C0C0C0;        // test the bytes for conform
  cmp  ebx,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;              // when not -> error
  cmp  eax,$F0908080;        // min value for 4 byte sequence
  jb   @foult4;              // < error
  cmp  eax,$F48FBFBF;        // max value for 4 Byte sequence
  ja   @foult4;              // > error
  add  esi,4;
  add  ecx,1;
  sub  edx,4;
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp edx,3;
  je  @err3;
  cmp edx,2;
  je  @err2;
  add ecx,1;
  sub edx,1;
  jle @ende;
 @err3:
  mov eax,dword ptr [esi];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult4:
  mov  ebx,3;
  bswap eax;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @a;
  add  ecx,1;
  jmp  @a;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @load;

align 16;
 @ende:
  mov  eax,ecx;              // Return count of UTF8 Chars
  pop  esi;
  pop  ebx;
 @stop:
end;


{ See UTF8Length but we count the chars needed from UTF8 coding
  to UTF16 coding.}

{$IFDEF FPC_HAS_CPSTRING}
function UTF8ToUTF16Length(const sText :Rawbytestring):Longint;register;
             assembler;nostackframe;
{$ELSE}
function UTF8ToUTF16Length(const sText :string):Longint;register;
             assembler;nostackframe;
{$ENDIF}

{ Input:
     eax = addres sText

   Output:
     eax = count of UTF8 chars in sText

   use the registers:
     eax = for tests
     edx = byte length from sText,
     ecx = counter of neded UTF16Char
     esi = source pointer
     ebx = for test

   Remark: The load of 4 byte for test BOM is ok, a string have a Nul byte
           at the end.
}

asm
  test eax,eax;              // test addres
  jz   @stop;
  push ebx;
  push esi;
  mov  esi,eax;              // Adress pointer
  xor  eax,eax;              // clear return
  xor  ecx,ecx;              // Counter
 {$IFDEF FPC_HAS_CPSTRING}
  (* description: test it's a real UTF8 string *)
  movzx edx,word ptr[esi-12]; // CodePage Info
  cmp  edx,65001;            // if UTF8string?
  jne  @ende;
 {$ENDIF}
  mov  edx,dword ptr[esi-4]; // string length
  cmp  edx,0;
  jle  @ende;
  jo   @ende;                // we have SIGNED Values!

  cmp  edx,3;                // if BOM possibility?
  jl   @Load;                // no, when < 3
  mov  eax,dword ptr[esi];   // we receive no error, we have a Nul byte at end!
  and  eax,$00FFFFFF;        // only 3 byte test
  cmp  eax,$00BFBBEF;        // UTF8 BOM?
  jne  @load;
  add  ecx,1;                // count BOM
  add  esi,3;                // yes, correct the source pointer
  sub  edx,3;                // and length of string
  jle  @ende;

align 16;
 @load:
  mov  al,byte ptr[esi];     // load start byte for test
  cmp  al,$80;               // ASCII code?
  jb   @start1;              // yes, 1 Byte
  cmp  al,$C2;               // value $80...$C1 can not be start sequenz
  jb   @foultcoding;
  cmp  al,$DF;               // 2 byte
  jbe  @start2;
  cmp  al,$EF;               // 3 byte
  jbe  @start3;
  cmp  al,$F4;               // 4 byte
  jbe  @start4;
  ja   @foultcoding;         // error coding

align 16
 @start1:                   // start byte sequence
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jg   @load;
  jle  @Ende;

align 16;
 @Start2:                    // start 2 byte sequence
  cmp  edx,2;
  jl   @foultcoding;
  movzx eax,word ptr[esi];
  bswap eax;                 // for better test
  mov  ebx,eax;
  and  ebx,$E0C00000;        // test of conform
  cmp  ebx,$C0800000;        // 110xxxxx 10xxxxxx
  jne  @foult2;
  cmp  eax,$C2800000;        // min value for 2 byte sequence
  jb   @foult2;
  cmp  eax,$DFBF0000;        // max value for 2 byte sequence
  ja   @foult2;
  add  esi,2;
  add  ecx,1;
  sub  edx,2;
  jg   @Load;
  jle  @Ende;

align 16;
 @foult2:
  bswap eax;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  ah,$80;
  jb   @Load;
  cmp  ah,$C2;
  jae  @Load;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start3:                   // start 3 byte sequence
  cmp  edx,3;
  jl   @foult30;
  mov  eax,dword ptr[esi];
  and  eax,$00FFFFFF;
  bswap eax;
  mov  ebx,eax;
  and  ebx,$F0C0C000;        // test for conform
  cmp  ebx,$E0808000;        // 1110xxxx 10xxxxxx 10xxxxxx
  jne  @foult3               // not conform -> error
  cmp  eax,$E0A08000;        // minimal 3 byte value
  jb   @foult3;
  cmp  eax,$EFBFBF00;        // maximal 3 byte value
  ja   @foult3;
  cmp  eax,$ED9FBF00;
  ja   @test31;
  add  esi,3;
  add  ecx,1;
  sub  edx,3;
  jg   @Load;
  jle  @Ende;

align 16;
 @test31:                   // special test
  cmp eax,$EE808000;
  jb  @foult3;              // when < surrogate range
  add esi,3;
  add ecx,1;
  sub edx,3;                 // only 3 bytes
  jg  @load;
  jle @ende;

align 16;
 @foult30:             // string length < 3 byte
  cmp edx,2;
  je  @error2;
  add ecx,1;
  sub edx,1;
  jle @ende;
 @error2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult3:
  mov  ebx,2;
  bswap eax;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$E0;          // test for special start byte
  je   @E0;
  cmp  al,$ED;          // dito
  je   @ED;
align 16;
 @1:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @1;
  add  ecx,1;
  jmp  @1;
align 16;
 @E0:                   // special test
  cmp  ah,$A0;
  jae  @1;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
align 16;
 @ED:                  // dito
  cmp  ah,$9F;
  jbe  @1;
  add  ecx,1;
  add  esi,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @Start4:                   // start  4 byte sequence
  cmp  edx,4
  jl   @foult40;
  mov  eax,dword ptr [esi];
  bswap eax;
  mov  ebx,eax;
  and  ebx,$F8C0C0C0;        // test the bytes for conform
  cmp  ebx,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;              // when not -> error
  cmp  eax,$F0908080;         // min value for 4 byte sequence
  jb   @foult4;              // < error
  cmp  eax,$F48FBFBF;        // max value for 4 Byte sequence
  ja   @foult4;              // > error
  add  esi,4;
  add  ecx,2;                // all UTF8 4 byte -> 2 utf16 chars
  sub  edx,4;
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp edx,3;
  je  @err3;
  cmp edx,2;
  je  @err2;
  add ecx,1;
  sub edx,1;
  jle @ende;
 @err3:
  mov eax,dword ptr [esi];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult4:
  mov  ebx,3;
  bswap eax;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  ebx,1;
  sub  edx,1;
  cmp  al,$BF;
  jbe  @a;
  add  ecx,1;
  jmp  @a;
align 16;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
align 16;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:
  add  esi,1;
  add  ecx,1;
  sub  edx,1;
  jg   @load;

align 16;
 @ende:
  mov  eax,ecx;              // Return count of UTF8 Chars
  pop  esi;
  pop  ebx;
 @stop:
end;

// itern use
procedure error_1;register;assembler;nostackframe;
 asm
  test ebp,ebp;               // check byte order
  jnz  @order;
  mov  word ptr[edi],$FFFD;  // mark invalid char on UTF16LE
  add  edi,2;
  jmp  @ende;
 @order:
  mov  word ptr[edi],$FDFF;
  add  edi,2;
 @ende:
end;

{ The function convert a string with the UTF8 coding on a string with
  the UTF16 coding. When the input string has a BOM, the function
  ignore the BOM. The result string will saved without BOM. The
  parameter OutByteOrder give the byte order for the result string.
  The function checked of a correct input coding. Ill codepoints are
  marked on result string. The result is the number of UTF16 chars.
}
{$IFDEF FPC_HAS_CPSTRING}
function UTF8ToUTF16(const sText :Rawbytestring; pUni16 :Pointer;
   OutByteOrder :TByteOrder):Longint; register;assembler;nostackframe;
{$ELSE}
function UTF8ToUTF16(const sText :string; pUni16 :Pointer;
   OutByteOrder :TByteOrder):Longint; register;assembler;nostackframe;
{$ENDIF}

(* Input:
     eax = addres sText
     edx = addres lpUnicodeChar
     ecx = OutByteOrder

   Output:
     eax = count of UTF16 chars
     lpUnicodeChar = result string UTF16 encoded on Outbyteorder

   use register:
     edx = sText length
     ebp = Outbyte order
     eax,ecx,ebx for convert
     esi = source addres
     edi = destination addres

*)

 asm
   push ebx;
   push esi;
   push edi;
   push ebp;
   push edx;                  // save the addres of lpUnicodeChar
   xor  ebp,ebp;
   cmp  cl,0;                 // ByteOrder
   setnz bl;                  // 0 = tyLE, 1 = tyBE
   movzx ebp,bl;
   mov  esi,eax;              // addres pointer for sText
   mov  edi,edx;              // addres pointer for pUnicodeChar
 {$IFDEF FPC_HAS_CPSTRING}
   (* description: test is a real UTF8 string *)
   movzx edx,word ptr[esi-12];
   cmp  edx,65001;            // if UTF8string?
   jne  @error;
 {$ENDIF}
   mov  edx,dword ptr[esi-4]; // string length
   cmp  edx,0;
   jle  @error;
   jo   @error;

   cmp  edx,3;                // if BOM possibility?
   jl   @Load;                // no, when < 3
   mov  eax,dword ptr[esi];   // load 4 byte from sText
   and  eax,$00FFFFFF;        // only 3 byte test
   cmp  eax,$00BFBBEF;        // UTF8 BOM?
   jne  @Load;
   add  esi,3;                // yes, correct the source pointer
   sub  edx,3;                // and length of string
   jle  @ende;

align 16;
  @Load:
   mov  al,byte ptr[esi];   // load start byte for test
   cmp  al,$80;               // ASCII code?
   jb   @start1;              // yes, 1 Byte
   cmp  al,$C2;               // value $80...$C1 can not be at start of sequenz
   jb   @foultcoding;
   cmp  al,$DF;               // 2 byte
   jbe  @start2;
   cmp  al,$EF;               // 3 byte
   jbe  @start3;
   cmp  al,$F4;               // 4 byte
   jbe  @start4;
   ja   @foultcoding;         // error coding

align 16;
  @start1:                    // we found 1 Byte sequence
   mov  ah,0;
   test ebp,ebp;              // 0 = tyLE
   jnz  @step11;              // coding for speed tyLE
   mov  word ptr[edi],ax;     // save the word
   add  edi,2;                // add destination pointer + 2
   add  esi,1;                // add source pointer + 1
   sub  edx,1;                // string length - 1
   jg   @Load;                // next byte
   jle  @ende;
align 16;
  @step11:
   xchg al,ah;                // byte order tyBE
   mov  word ptr[edi],ax;     // save the word
   add  edi,2;                // add destination pointer + 2
   add  esi,1;                // add source pointer + 1
   sub  edx,1;                // string length - 1
   jg   @Load;                // next byte
   jle  @ende;

align 16;
  @Start2:
   cmp  edx,2;                // string length >= 2 byte?
   jl   @foultcoding;         // no, error
   movzx eax,word ptr[esi];   // load the 2 byte sequence
   bswap eax;
   mov  ecx,eax;              // save for lather
   and  ecx,$E0C00000;        // test of conform
   cmp  ecx,$C0800000;        // 110xxxxx 10xxxxxx
   jne  @foult2;
   cmp  eax,$C2800000;        // min value range
   jb   @foult2;
   cmp  eax,$DFBF0000;        // max value range
   ja   @foult2;
   bswap eax;                 // correct the byte order
   mov  ecx,eax;              // double the value
   and  ecx,$00003F1F;        // and the first byte with 1F second with 3F
   xor  ebx,ebx;              // clear
   mov  bl,al;
   shl  bl,6;                 // first byte shl 6
   shr  eax,8;                // second byte -> al
   or   eax,ebx;              // result is UTF16 coding
   test ebp,ebp;              // 0 = tyLE
   jnz  @step21;              // following construct is speed for tyLE
   mov  word ptr[edi],ax;     // save the result
   add  edi,2;                // destination pointer + 2
   add  esi,2;                // add source pointer + 2
   sub  edx,2;                // string length - 2
   jg   @Load;                // sub set all flags
   jle  @ende;                // so we avoid the use of jmp! jmp cost time
align 16;
  @step21:
   xchg al,ah;                // correct the byte order (UTF16BE)
   mov  word ptr[edi],ax;     // save the result
   add  edi,2;                // destination pointer + 2
   add  esi,2;                // add source pointer + 2
   sub  edx,2;                // string length - 2
   jg   @Load;
   jle  @ende;

align 16;
 @foult2:
  bswap eax;
  call error_1;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  ah,$80;
  jb   @Load;
  cmp  ah,$C2;
  jae  @Load;
  call error_1;
  add  esi,1;
  sub  edx,1;
  jg   @load;
  jle  @ende;

align 16;
  @start3:                    // found a 3 byte sequence
   cmp  edx,3                 // string length >= 3 byte
   jl   @foult30;             // error
   mov  eax,dword ptr[esi];   // load 4 Byte
   and  eax,$00FFFFFF;        // clear byte 4, only 3 byte
   bswap eax;
   mov  ecx,eax;              // load the saved value
   and  ecx,$F0C0C000;        // test for conform
   cmp  ecx,$E0808000;        // 1110xxxx 10xxxxxx 10xxxxxx
   jne  @foult3;              // not conform -> error
   cmp  eax,$E0A08000;        // min value for 3 byte sequence
   jb   @foult3;
   cmp  eax,$EFBFBF00;        // max value for 3 byte sequence
   ja   @foult3;
   cmp  eax,$ED9FBF00;
   ja   @step3;
  @step31:
   bswap eax;                 // correct the byte order
   and  eax,$003F3F0F;        // here all and's for the bytes
   xor  ebx,ebx;
   xor  ecx,ecx;
   mov  bl,al;                // 1 Byte and 0F shl 12
   shl  ebx,12;
   mov  cl,ah;                // 2 Byte and 3F shl 6
   shl  ecx,6;
   or   ebx,ecx;              // inter result
   shr  eax,16;               // 3 Byte -> al and 3F
   or   eax,ebx;              // result UTF16 coding
   test ebp,ebp;              // 0 = tyLE
   jnz  @step32;              // coding for speed tyLE
   mov  word ptr[edi],ax;     // save the word
   add  edi,2;                // destination pointer + 2
   add  esi,3;                // add source pointer + 3
   sub  edx,3;                // string length - 3
   jg   @Load;
   jle  @ende;
align 16;
  @step32:
   xchg al,ah;                // correct the byte order (UTF16BE)
   mov  word ptr[edi],ax;     // save the word
   add  edi,2;                // destination pointer + 2
   add  esi,3;                // add source pointer + 3
   sub  edx,3;                // string length - 3
   jg   @Load;
   jle  @ende;

align 16;
 @step3:
  cmp eax,$EE808000;
  jb  @foult3;               // when < surrogate range
  jae @step31;

align 16;
 @foult30:             // string length < 3 byte
  cmp  edx,2;
  je   @error2;
  jmp  @foultcoding;
 @error2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult3:
  mov  ebx,2;
  bswap eax;
  call error_1;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$E0;          // test for special start byte
  je   @E0;
  cmp  al,$ED;          // dito
  je   @ED;
align 16;
 @1:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @1;
  call error_1;
  jmp  @1;
align 16;
 @E0:                   // special test
  cmp  ah,$A0;
  jae  @1;
  add  esi,1;
  call error_1
  sub  edx,1;
  jg   @Load;
  jle  @ende;
align 16;
 @ED:                  // dito
  cmp  ah,$9F;
  jbe  @1;
  call error_1;
  add  esi,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
  @Start4:                    //found 4 byte sequence
   cmp  edx,4                 // string lengt >= 4 Byte
   jl   @foult40;
   mov  eax,dword ptr [esi];  // load 4 byte
   bswap eax;
   mov  ecx,eax;              // double the value
   and  ecx,$F8C0C0C0;        // test the bytes for conform
   cmp  ecx,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
   jne  @foult4;              // when not -> error
   cmp  eax,$F0908080;        // minimal value for 4 byte sequence
   jb   @foult4;              // < error
   cmp  eax,$F48FBFBF;        // maximal value for 4 Byte sequence
   ja   @foult4;              // > error
   bswap eax;                 // bswap for correct byte order
   and  eax,$3F3F3F07;        // and all the 4 byte
   xor  ebx,ebx;              // clear ebx
   xor  ecx,ecx;              // clear ecx
   mov  bl,al;                // 1 Byte and 07 shl 18
   shl  ebx,18;
   mov  cl,ah;                // 2 Byte and 3F shl 12
   shl  ecx,12;
   or   ebx,ecx;              // inter result
   shr  eax,16;               // 3 and 4 byte -> ax
   xor  ecx,ecx;              // clear ecx
   mov  cl,al;                // 3 Byte and 3F shl 6
   shl  ecx,6;
   or   ebx,ecx;              // inter result
   shr  eax,8;                // 4 Byte and 3F
   or   eax,ebx;              // result UTF16 coding
   sub  eax,$10000;           // subtract 65536 from UTF16 word
   mov  ebx,eax;              // save the result
   shr  eax,10;               // result div 1024
   add  eax,$D800;            // low surrogate = result + 55296
   test ebp,ebp;              // 0 = tyLE
   jz   @stepd1;
   xchg al,ah;                // byte order tyBE
  @stepd1:
   mov  word ptr[edi],ax;     // save the low surrogate UTF16 coding
   add  edi,2;                // destination pointer + 2
   and  ebx,$3FF;             //
   add  ebx,$DC00;            // high surrogate = result + 56320
   test ebp,ebp;              // 0 = tyLE
   jz   @stepd2;
   xchg bl,bh;                // byte order tyBE
  @stepd2:
   mov  word ptr[edi],bx;     // save the high surrogate UTF16 coding
   add  edi,2;                // destination pointer + 2
   add  esi,4;                // add source pointer + 4
   sub  edx,4;                // string length - 4
   jg   @Load;
   jle  @ende;

align 16;
 @foult40:
  cmp edx,3;
  je  @err3;
  cmp edx,2;
  je  @err2;
  jmp @foultcoding;          // only 1 byte
 @err3:
  mov eax,dword ptr [esi];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult4:
  mov  ebx,3;
  bswap eax;
  add  esi,1;
  call error_1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @a;
  call error_1;
  jmp  @a;
align 16;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  esi,1;
  call error_1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
align 16;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  esi,1;
  call error_1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:
  add  esi,1;
  test ebp,ebp;              // check byte order
  jnz  @order;
  mov  word ptr[edi],$FFFD;  // mark invalid char on UTF16LE
  add  edi,2;
  sub  edx,1;                // string length -1
  jg   @load;
  jle  @ende;
align 16;
 @order:
  mov  word ptr[edi],$FDFF;  // UTF8BE
  add  edi,2;
  sub  edx,1;                // string length -1
  jg   @load;
  jle  @ende;

align 16;
 @error:
  pop  edx;                  // addres of lpUnicodeChar
  xor  eax,eax;              // Nul;
  jmp  @go;

align 16;
 @ende:
  pop  edx;                  // addres of lpUnicodeChar
  mov  word ptr[edi],$0000;  // double Nul for UTF16 string
  sub  edi,edx;              // calculate the bytes
  mov  eax,edi;              // string length in byte
  shr  eax,1;                // quantity of UTF16 chars
 @go:
  pop  ebp;
  pop  edi;
  pop  esi;
  pop  ebx;
 @stop:
end;

{ The function convert a string with the UTF8 coding on a string with
  the UTF32 coding. When the input string have a BOM, this is not
  relevant and will ignoring. The output string will saved without a
  BOM. Ill codepoints on input string is marked result string. The result
  is the number of UTF32 chars.
  UTF32 will only use on computer internal and not for change data with
  other operating system. Windows use tyLE and so no other byte order
  is need.
}
{$IFDEF FPC_HAS_CPSTRING}
function UTF8ToUTF32(const sText :Rawbytestring; pUCS4Char :Pointer):Longint;
     register;assembler;nostackframe;
{$ELSE}
function UTF8ToUTF32(const sText :string; pUCS4Char :Pointer):Longint;
     register;assembler;nostackframe;
{$ENDIF}

{ Input:
     eax = addres sText
     edx = addres lpUCS4Char
   Output:
     eax = result count of UTF32 Chars
     lpUCS4Char = addres of the result string

   use registers:
     edx = text length
     eax,ecx,ebx for convert
     esi = source addres
     edi = destination addres
}

asm
  push ebx;
  push esi;
  push edi;
  push edx;                  // save the addres of lpUCS4Char
  mov  esi,eax;              // addres pointer for sText
  mov  edi,edx;              // addres pointer for lpUCS4Char
{$IFDEF FPC_HAS_CPSTRING}
  (* description: test is a real UTF8 string *)
  movzx edx,word ptr[esi-12];
  cmp  edx,65001;            // if UTF8string?
  jne  @error;
{$ENDIF}
  mov  edx,dword ptr[esi-4]; // string length
  cmp  edx,0;
  jle  @error;
  jo   @error;

  cmp  edx,3;                // if BOM possibility?
  jl   @Load;                // no, when < 3
  mov  eax,dword ptr[esi];   // load 4 byte from sText
  and  eax,$00FFFFFF;        // only 3 byte test
  cmp  eax,$00BFBBEF;        // UTF8 BOM?
  jne  @Load;
  add  esi,3;                // yes, correct the source Pointer
  sub  edx,3;
  jle  @error;               // only BOM -> error

align 16;
 @Load:
  mov  al,byte ptr[esi];     // load start byte for test
  cmp  al,$80;               // ASCII code?
  jb   @start1;              // yes, 1 Byte
  cmp  al,$C2;               // value $80...$C1 can not be at start of sequenz
  jb   @foultcoding;
  cmp  al,$DF;               // 2 byte
  jbe  @start2;
  cmp  al,$EF;               // 3 byte
  jbe  @start3;
  cmp  al,$F4;               // 4 byte
  jbe  @start4;
  ja   @foultcoding;         // error coding

align 16;
 @start1:                    // we found 1 Byte sequence
  and  eax,$000000FF;        // clear the upper bytes
  mov  dword ptr[edi],eax;   // save the UTF32 char
  add  edi,4;                // add destination pointer + 4
  add  esi,1;                // add source pointer + 1
  sub  edx,1;                // string length - 1
  jg   @Load;
  jle  @ende;

align 16;
 @Start2:
  cmp  edx,2;                // string length >= 2 byte?
  jl   @foultcoding;         // no, error
  movzx eax,word ptr[esi];   // load the 2 byte sequence
  bswap eax;
  mov  ecx,eax;              // save for lather
  and  ecx,$E0C00000;        // test of conform
  cmp  ecx,$C0800000;        // 110xxxxxx 10xxxxxx
  jne  @foult2;
  cmp  eax,$C2800000;        // min value range
  jb   @foult2;
  cmp  eax,$DFBF0000;        // max value range
  ja   @foult2;
  bswap eax;                 // correct the byte order
  mov  ecx,eax;              // save the value
  and  eax,$00003F1F;        // and the bytes
  xor  ebx,ebx;              // clear ebx;
  mov  bl,al;                // save al = al and 1F -> bl
  shl  bl,6;                 // first Byte and 1F shl 6,
  shr  eax,8;                // second Byte 3F in al
  or   eax,ebx;              // result a UTF16 word
  and  eax,$0000FFFF;        // result UTF32
  mov  dword ptr[edi],eax;   // save the result
  add  edi,4;                // destination pointer + 2
  add  esi,2;                // add source pointer + 2
  sub  edx,2;                // string length - 2
  jg   @Load;
  jle  @ende;

align 16;
 @foult2:
  bswap eax;
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jle  @ende;
  cmp  ah,$80;
  jb   @Load;
  cmp  ah,$C2;     // a start byte?
  jae  @Load;
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jg   @load;
  jle  @ende;


align 16;
 @start3:                    // found a 3 byte sequence
  cmp  edx,3                 // string length >= 3 byte
  jl   @foult30;             // error
  mov  eax,dword ptr[esi];   // load 4 Byte
  and  eax,$00FFFFFF;        // clear byte 4
  bswap eax;
  mov  ecx,eax;              // save for lather
  and  ecx,$F0C0C000;        // test for conform
  cmp  ecx,$E0808000;        // 1110xxxx 10xxxxxx 10xxxxxx
  jne  @foult3;
  cmp  eax,$E0A08000;        // min value for 3 byte sequence
  jb   @foult3;
  cmp  eax,$EFBFBF00;        // max value for 3 byte sequence
  ja   @foult3;
  cmp  eax,$ED9FBF00;
  ja   @step3;
 @step31:
  bswap eax;                 // correcte byte order
  and  eax,$003F3F0F;        // and all the bytes
  xor  ebx,ebx;              // clear ebx
  xor  ecx,ecx;              // clear ecx
  mov  bl,al;                // 1 Byte -> bl
  shl  ebx,12;               // byte 1 = bl and 0F shl 12
  mov  cl,ah;                // 2 Byte -> cl
  shl  ecx,6;                // byte 2 = cl and 3F shl 6;
  or   ebx,ecx;              // inter result bl or cl
  shr  eax,16;               // 3 byte = and EF
  or   eax,ebx;              // result UTF32 coding
  mov  dword ptr[edi],eax;   // save the UTF32 coding
  add  edi,4;                // destination + 4
  add  esi,3;                // source pointer + 3
  sub  edx,3;                // string length - 3
  jg   @Load;
  jle  @ende;

align 16;
 @step3:
  cmp eax,$EE808000;
  jb  @foult3;
  jae @step31;

align 16;
 @foult30:             // string length < 3 byte
  cmp  edx,2;
  je   @error2;
  jmp  @foultcoding;
 @error2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult3:
  mov  ebx,2;
  bswap eax;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  add  esi,1;
  sub  edx,1;
  jle  @ende;
  cmp  al,$E0;          // test for special start byte
  je   @E0;
  cmp  al,$ED;          // dito
  je   @ED;
align 16;
 @1:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  jmp  @1;
align 16;
 @E0:                   // special test
  cmp  ah,$A0;
  jae  @1;
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
align 16;
 @ED:                  // dito
  cmp  ah,$9F;
  jbe  @1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  add  esi,1;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @Start4:                    //found 4 byte sequence
  cmp  edx,4                 // string lengt >= 4 Byte
  jl   @foult40;
  mov  eax,dword ptr [esi];  // load 4 byte
  bswap eax;
  mov  ecx,eax;              // double the value
  and  ecx,$F8C0C0C0;        // test the bytes for conform
  cmp  ecx,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;
  cmp  eax,$F0908080;        // minimal value for 4 byte sequence
  jb   @foult4;              // < error
  cmp  eax,$F48FBFBF;        // maximal value for 4 Byte sequence
  ja   @foult4;              // > error
  bswap eax;                 // correct the byte order
  and  eax,$3F3F3F07;
  xor  ebx,ebx;              // clear ebx
  xor  ecx,ecx;              // clear ecx
  mov  bl,al;                // first Byte al and 07 shl 18
  shl  ebx,18;
  mov  cl,ah;                // second Byte ah and 3F shl 12
  shl  ecx,12;
  or   ebx,ecx;              // first or second byte
  shr  eax,16;               // byte 3 and 4 -> ax
  xor  ecx,ecx;              // clear ecx
  mov  cl,al;                // 3 Byte
  shl  ecx,6;                // byte 3 and 3F shl 6
  or   ebx,ecx;              // or all the inter results
  shr  eax,8;                // 4 Byte and 3F
  or   eax,ebx;              // or all -> UTF32 coding
  mov  dword ptr[edi],eax;   // save the UTF32 coding
  add  edi,4;                // add destination + 4
  add  esi,4;                // source pointer + 4
  sub  edx,4;                // string length - 4
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp edx,3;
  je  @err3;
  cmp edx,2;
  je  @err2;
  jmp @foultcoding;
 @err3:
  mov eax,dword ptr [esi];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [esi];
  bswap eax;

align 16;
 @foult4:
  mov  ebx,3;
  bswap eax;
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  edx,0;
  jle  @ende;
  cmp  ebx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  esi,1;
  sub  edx,1;
  sub  ebx,1;
  cmp  al,$BF;
  jbe  @a;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  jmp  @a;
align 16;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jg   @Load;
  jle  @ende;
align 16;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:
  add  esi,1;
  mov  dword ptr[edi],$0000FFFD; // mark invalid char
  add  edi,4;
  sub  edx,1;
  jg   @load;
  jle  @ende;

align 16;
 @error:
  pop  edx;
  xor  eax,eax;              // Nul;
  jmp  @go;

align 16;
 @ende:
  pop  edx;                  // addres of lpUnicodeChar
  mov  dword ptr[edi],0;     // Nul dword
  add  edi,4;
  sub  edi,edx;
  mov  eax,edi;              // array length in byte
  shr  eax,2;                // UTF32 chars
 @go:
  pop  edi;
  pop  esi;
  pop  ebx;
 @stop:
end;


(*-----------------------UTF16--------------------------------------------*)

{ The function convert a UTF16 coded string on a UTF8 coded string.
  The byte order from the input string is on parameter InByteOrder.
  Has the input string a BOM, then the function compare the input
  parameter with the BOM. On case of a diffrent the function stop
  the converting and give a Nul string as result. Ill codepoints on
  the input string will marked on result string. The result string is
  saved without BOM. The function result is the number of UTF8 bytes.
 }
function UTF16ToUTF8(const sText :Unicodestring; pUTF8 :Pointer;
  InByteOrder :TByteOrder):Longint;register;assembler;nostackframe;

{ Input:
     eax = addres sText
     edx = addres pUTF8 pointer
     ecx = ByteOrder; 0 = tyLE, 1 = tyBE

   Output:
     eax   = string length on bytes
     pUTF8 = addres of converted string

   register use:
     edx = string length
     eax,ecx,ebx for convert
     esi = source addres
     edi = destination addres
     ebp = bit 0 is Byte order 0 = tyLE, 1 = tyBE and on
           Bit 30 surrotest flag
}
 asm
   push ebx;
   push esi;
   push edi;
   push ebp;
   push edx;                  // save the addres of pUTF8
   mov  ebp,ecx;              // ByteOrder
   mov  esi,eax;              // addres sText
   mov  edi,edx;              // addres pUTF8
   mov  edx,dword ptr[esi-4]; // count of chars
  {$IFDEF VER2_6_4}
   shr  edx,1                 // we need the chars for consistence
                              // FPC264 give the bytes
  {$ENDIF}
   cmp  edx,0;
   jl   @error;               // when < 2 byte
   jo   @error;               // we have SIGNED value

   //BOM
   movzx eax,word ptr[esi];
   cmp  eax,$0000FEFF;        // UTF16LE   RFC2781
   je   @LE0;
   cmp  eax,$0000FFFE;        // UTF16BE   RFC2781
   je   @BE;
   jmp  @a1;

  @BE:
   cmp  ebp,0;                // 0 = tyLE
   jz   @error                // different BOM = BE but ByteOrder = LE
   jmp  @step00;
  @LE0:
   cmp  ebp,0;                // 0 = tyLE
   jnz  @error                // different BOM = LE but ByteOrder = BE
  @step00:
   add  esi,2;                // string start with BOM
   sub  edx,1;
   jle  @error;               // only BOM -> error
  @a1:
   cmp  ebp,0;
   je   @LoadLE;
   jne  @loadBE;


(* for UTF16LE (intel) *)
align 16;
 @loadLE:
  movzx eax,word ptr[esi];   // load UTF16 char
  cmp  eax,$80;              // check the bytes for convert on UTF8
  jb   @Start1;              // 1 Byte convert, is ASCII
  cmp  eax,$800;
  jb   @Start2;              // 2 byte convert
  cmp  eax,$D800;
  jb   @start3;
  cmp  eax,$FFFD;            // error mark
  je   @foultcoding;         // set UTF8Error mark
  cmp  eax,$DFFF;            // is 4 byte
  jbe  @surroLE;
  ja   @start3;
  // from E000..FFFF is priv zone convert to 3 byte

(* for UTF16BE *)
align 16;
 @loadBE:
  movzx eax,word ptr[esi];   // load UTF16 char
  xchg al,ah;
  cmp  eax,$80;              // check the bytes for convert on UTF8
  jb   @Start1;              // 1 Byte convert, is ASCII
  cmp  eax,$800;
  jb   @Start2;              // 2 byte convert
  cmp  eax,$D800;
  jb   @start3;
  cmp  eax,$FDFF;            // error mark for speed
  je   @foultcoding;         // set UTF8Error mark
  cmp  eax,$DFFF;            // is 4 byte
  jbe  @surroBE;

align 16;
 @Start3:                    // convert on 3 byte
  mov  ecx,eax;              // save for later
  shr  ecx,12;
  or   ecx,$0000E0;          // 1 Byte
  mov  byte ptr[edi],cl;
  add  edi,1;
  mov  ecx,eax;
  shr  ecx,6;
  and  ecx,$0000003F;
  or   ecx,$00000080;        // 2 Byte
  mov  byte ptr[edi],cl;
  add  edi,1;
  mov  ecx,eax;
  and  ecx,$0000003F;
  or   ecx,$00000080;        // 3 Byte
  mov  byte ptr[edi],cl;
  add  edi,1;
  add  esi,2;
  sub  edx,1;
  jle  @ende;
  cmp  ebp,0;                // 0 = tyLE
  je   @loadLE;
  jne  @LoadBE;;

align 16;
 @Start2:                    // convert 2 byte
  mov  ecx,eax;              // save for later
  shr  ecx,6;
  or   ecx,$000000C0;        // 1 byte;
  mov  byte ptr[edi],cl;
  add  edi,1;
  and  eax,$0000003F;
  or   eax,$00000080;        // 2 byte
  mov  byte ptr[edi],al;
  add  edi,1;
  add  esi,2;
  sub  edx,1;
  jle  @ende;
  cmp  ebp,0;
  je   @loadLE;
  jne  @LoadBE;;

align 16;
 @Start1:
  mov  byte ptr[edi],al;
  add  edi,1;
  add  esi,2;
  sub  edx,1;
  jle  @ende;
  cmp  ebp,0;
  je   @loadLE;
  jne  @LoadBE;;

align 16;
 @surroBE:                     // we found a surrogate word
  cmp  edx,2;
  jle  @foultcoding0;
  mov  eax,dword ptr[esi];     // load is ok string has Nul word at end
  bswap eax;
  rol  eax,16;
  jmp  @LE;

align 16;
 @surroLE:
  cmp  edx,2;
  jle  @foultcoding0;
  mov  eax,dword ptr[esi];
 @LE:
  mov  ecx,eax;              // both words
  and  ecx,$0000FFFF;        // test range for high surrogate
  cmp  ecx,$D800;            // high surro must be first!
  jb   @foultcoding;
  cmp  ecx,$DBFF;
  ja   @foultcoding;
  mov  ecx,eax;              // test range for low surrogate
  shr  ecx,16;
  cmp  ecx,$DC00;
//  jb   @foultcoding2;
  jb   @foultcoding;
  cmp  ecx,$DFFF;
  ja   @priv;
  // E0000...FFFF is priv. zone

  mov  ecx,eax;              // bring saved value to ecx
  mov  ebx,eax;
  and  ecx,$0000FFFF;        // high surro
  sub  ecx,$D800;
  shl  ecx,10;
  shr  ebx,16;
  sub  ebx,$DC00;
  add  ebx,$10000;
  add  ecx,ebx               // we have a UTF32 value
  mov  ebx,ecx;              // save the UTF32 value
  shr  ecx,18;               // convert 1 byte
  or   ecx,$000000F0;
  mov  byte ptr[edi],cl;
  add  edi,1;
  mov  ecx,ebx;              // 2 byte
  shr  ecx,12;
  and  ecx,$0000003F;
  or   ecx,$00000080;
  mov  byte ptr[edi],cl;
  add  edi,1;
  mov  ecx,ebx;              // 3 byte
  shr  ecx,6;
  and  ecx,$0000003F;
  or   ecx,$00000080;
  mov  byte ptr[edi],cl;
  add  edi,1;
  and  ebx,$0000003F;       // 4 bytes
  or   ebx,$00000080;
  mov  byte ptr[edi],bl;
  add  edi,1;
  add  esi,4;
  sub  edx,2
  jle  @ende;
  cmp  ebp,0;
  je   @LoadLE;
  jne  @loadBE;

align 16;
 @priv:
  mov dword ptr[edi],$BDBFEF; // foult coding we have surro before
  add edi,3;
  add esi,2;                  // the other 2 bytes is on Start3!
  sub edx,1;                  
  mov eax,ecx;                // the value is in ecx for work
  jmp @start3;                // convert to 3 byte

//align 16;
// @foultcoding2:
//  mov dword ptr[edi],$BDBFEF; // part 2 from surro is ill coding
//  add edi,3;                  // mark both
//  add esi,2;
//  sub edx,2;
align 16;
 @foultcoding:
  mov dword ptr[edi],$BDBFEF; // part 1 from surro is ill coding
  add edi,3;
  add esi,2;
  sub edx,1;
  jle @ende;
  cmp ebp,0;
  je  @LoadLE;
  jne @loadBE;

align 16;
 @error:
  pop  edx;
  xor  eax,eax;              // Nul
  jmp  @go;

 @foultcoding0:
  mov dword ptr[edi],$00BDBFEF;
  add edi,3;
  // all words processed

align 16;
 @ende:
  pop  edx;                  // addres of pUTF8
  mov  byte ptr[edi],$0;     // Nul Byte
  sub  edi,edx;
  mov  eax,edi;              // string length in Byte
 @go:
  pop  ebp;
  pop  edi;
  pop  esi;
  pop  ebx;
 @stop:
 end;

{ The function convert a UTF16 coded string on a UTF32 coded string. The
  byte order from the input string is on parameter InByteOrder. Has the
  input string a BOM then the function compare this with the input of
  value in InByteOrder. On case of a diffrent the function stop and give
  a Nul string as result. The result string is saved without BOM. The result
  string has the tyLE order(UCS4strings normal only used in working system).
  ill codepoints of the input string will marked on result string.
  The function result is the number of UTF32 chars.
}
function UTF16ToUTF32(const sText :Unicodestring; pUCS4 :Pointer;
  InByteOrder :TByteOrder):Longint;register;assembler;nostackframe;

{ Input:
     eax = addres sText
     edx = addres pUCS4 Pointer
     ecx = byte order

   Output:
     eax   = count of UCS4chars
     pUCS4 = addres of the converted string

   register:
     edx = string length
     eax,ecx for convert
     esi = source addres
     edi = destination addres
     ebp for byte order; 1 = UTF16BE 0 = UTF16LE
}

 asm
   push esi;
   push edi;
   push ebp;
   push edx;                  // save the addres of pUCS4!
   mov  ebp,ecx;              // ByteOrder
   mov  esi,eax;              // addres for sText
   mov  edi,edx;              // addres for pUCS4
   mov  edx,dword ptr[esi-4]; // count of chars
  {$IFDEF VER2_6_4}
   shr  edx,1                 // we need count of chars for consistence with older
                              // FPC264 give byte not char
  {$ENDIF}
   cmp  edx,0;
   jl   @ende;                // when < 2 byte
   jo   @ende;

   //BOM
   movzx eax,word ptr[esi];
   cmp  eax,$0000FEFF;        // UTF16LE   RFC2781
   je   @LE;
   cmp  eax,$0000FFFE;        // UTF16BE   RFC2781
   je   @BE;
   jmp  @a1;

  @BE:
   test ebp,ebp;             // 0 = tyLE
   jz   @error;              // different BOM = BE but byteorder = tyLE
   jmp  @step00;
  @LE:
   test ebp,ebp;             // 0 = tyLE
   jnz  @error;              // different BOM = LE but byteorder = tyBE
  @step00:
   add  esi,2;               // add source pointer + 2
   sub  edx,1                // string length
   jle  @error;              // only BOM -> error
  @a1:
   cmp  ebp,0;
   jne  @loadBE;

(* for UTF16LE (intel) *)
align 16;
 @loadLE:
  movzx eax,word ptr[esi];   // load UTF16 char
  cmp  eax,$FFFD;            // error mark
  je   @foult1;
  cmp  eax,$D800;
  jae  @surroLE;
  mov  dword ptr[edi],eax;   // save the UTF32 coding
  add  edi,4;
  add  esi,2;
  sub  edx,1;
  jg   @LoadLE;
  jle  @ende;

align 16;
 @surroLE:
  cmp  eax,$0000DFFF;
  ja   @priv0;
  cmp  edx,2;
  jle  @foult0;
  mov  eax,dword ptr[esi];
  mov  ecx,eax;              // both words
  and  ecx,$0000FFFF;        // test range for high surrogate
  cmp  ecx,$D800;            // high surrogate must be first!
  jb   @foult1;
  cmp  ecx,$DBFF;
  ja   @foult1;
  mov  ecx,eax;
  shr  ecx,16;
  cmp  ecx,$DC00;            // test range for low surrogate
//  jb   @foultcoding2;
  jb   @foult1;
  cmp  ecx,$DFFF;
  ja   @priv;                // is from priv. zone

  mov  ecx,eax;              // bring saved value to ecx
  and  ecx,$0000FFFF;        // high surro
  sub  ecx,$D800;
  shl  ecx,10;
  shr  eax,16;
  sub  eax,$DC00;            // low surro
  add  eax,$10000;
  add  ecx,eax               // we have a UTF32 value
  mov  dword ptr[edi],ecx;
  add  edi,4;
  add  esi,4;
  sub  edx,2;                // all 2 words processed
  jg   @LoadLE;
  jle  @ende;


(* for UTF16BE *)
align 16;
 @loadBE:
  movzx eax,word ptr[esi];  // load UTF16 char
  xchg al,ah;
  cmp  eax,$FFFD;           // error mark
  je   @foult1;
  cmp  eax,$D800;
  jae  @surroBE;
  mov  dword ptr[edi],eax;   // save the UTF32 coding
  add  edi,4;                // add destination + 4
  add  esi,2;
  sub  edx,1;
  jg   @LoadBE;
  jle  @ende;

align 16;
 @surroBE:
  cmp  eax,$0000DFFF;
  ja   @priv0;               // E000...FFFF is priv. zone
  cmp  edx,2;
  jle  @foult0;
  mov  eax,dword ptr[esi];
  bswap eax;
  rol  eax,16;
  mov  ecx,eax;
  and  ecx,$0000FFFF;        // test range for high surrogate
  cmp  ecx,$D800;            // high surrogate must be first!
  jb   @foult1;
  cmp  ecx,$DBFF;
  ja   @foult1;
  mov  ecx,eax;
  shr  ecx,16;
  cmp  ecx,$DC00;            // test range for low surrogate
//  jb   @foultcoding2;
  jb   @foult1;
  cmp  ecx,$DFFF;
  ja   @priv;                // is from priv. zone

  mov  ecx,eax;              // bring saved value to ecx
  and  ecx,$0000FFFF;        // high surro
  sub  ecx,$D800;
  shl  ecx,10;
  shr  eax,16;
  sub  eax,$DC00;            // low surro
  add  eax,$10000;
  add  ecx,eax               // we have a UTF32 value
  mov  dword ptr[edi],ecx;
  add  edi,4;
  add  esi,4;
  sub  edx,2;                // all 2 words processed
  jg   @LoadBE;
  jle  @ende;

align 16;
 @priv:
  mov dword ptr[edi],$0000FFFD; // foult coding, surro before
  add edi,4;
  add esi,2;
  sub edx,1;
  mov eax,ecx;
align 16;
 @priv0:
  mov dword ptr[edi],eax;      // value from E000...FFFF!
  add edi,4;
  add esi,2;
  sub edx,1;
  jle @ende;
  cmp ebp,0;
  je  @loadLE;
  jne @loadBE;

//align 16;
// @foultcoding2:
//  mov dword ptr[edi],$0000FFFD; // part 2 of surro is ill coding
//  add edi,4;                    // mark both
//  add esi,2;
//  sub edx,2;
align 16;
 @foult1:
  mov dword ptr[edi],$0000FFFD;
  add edi,4;
  add esi,2;
  sub edx,1;
  jle @ende;
  cmp ebp,0;
  je  @loadLE;
  jne @loadBE;

align 16;
 @error:
  pop  edx;
  xor  eax,eax;              // Nul Byte
  jmp  @go;

align 16;
 @foult0:
  mov  dword ptr[edi],$0000FFFD;
  add  edi,4;
  // all word processed

align 16;
 @ende:
  pop  edx;
  mov  dword ptr[edi],0;    // Nul dword
  add  edi,4;
  sub  edi,edx;
  mov  eax,edi;              // Size on byte
  shr  eax,2;                // chars on string
 @go:
  pop  ebp;
  pop  edi;
  pop  esi;
 @stop:
end;

(*-------------------------UTF32-------------------------------------------*)

{ The function count the chars for the convert from a UTF32 coded string
  to a UTF8 coded string. The function also count ill codepoints. The
  result is the number of UTF8 bytes.
}
function UTF32ToUTF8Length(constref sText :UCS4String):Longint;
    register;assembler;nostackframe;

{ Input:
     eax = sText,

   Output:
     eax = count of UTF8 byte for convert

   register use:
     ecx = counter of byte
     edx = array counter
     esi = addres of stext

   Remark: We count also ill codepoints.
}
  asm
   test eax,eax;
   jz   @Stop;
   push esi;
   xor  ecx,ecx;              // clear counter
   mov  esi,dword ptr[eax];   // addres sText
   mov  edx,dword ptr[esi-4]; // count of UCS4 chars
   cmp  edx,0;
   jle  @ende;
   jo   @ende;                // SIGNED value
   mov  eax,dword ptr[esi];   // load first dword
   cmp  eax,$FFFE0000;        // BOM UTF32BE -> stop
   je   @ende;
   cmp  eax,$0000FEFF;        // BOM? UTF32LE
   jne  @load;
   add  ecx,3;                // count BOM we not use BOM but for exact count
   add  esi,4;                // array start with BOM
   sub  edx,1;
   jle  @ende;                // only BOM -> error

align 16;
  @load:
   mov  eax,dword ptr[esi];
   add  esi,4;                // add addres pointer + 4
   cmp  eax,$80;
   jb   @Start1;               // convert to 1 byte
   cmp  eax,$800;
   jb   @Start2;               // convert to 2 byte
   // error coding $FFFD -> $EFBFBD on UTF8
   cmp  eax,$10000;
   jb   @Start3;               // convert to 3 byte
   cmp  eax,$10FFFF;           // ill coding on UTF32 convert to 3 byte error
   ja   @Start3;               // error
   // -> jbe  start4

  //Start4
   add  ecx,4;
   sub  edx,1;                  // array counter - 1
   jg   @Load;
   jle  @ende;

align 16;
  @Start1:
   add  ecx,1;
   sub  edx,1;
   jg   @Load;
   jle  @ende;

align 16;
  @Start2:
   add  ecx,2;
   sub  edx,1;
   jg   @Load;
   jle  @ende;

align 16;
  @Start3:
   add  ecx,3;
   sub  edx,1;
   jg   @Load;

align 16;
  @ende:
   mov  eax,ecx;              // UTF8 length on Byte
   pop  esi;
  @stop:
 end;

{ The function count the chars for the convert from a UTF32 coding to a
   UTF16 coding. The function result is the number of UTF16 chars.
}
function UTF32toUTF16Length(constref sText :UCS4string) :Longint;
       register;assembler;nostackframe;

{ Input:
      eax = sText,

   Output
      eax = count of UTF16 chars

   register use:
     ecx = counter of char
     edx = array counter from high to low
     esi = addres of stext

   Remark: we count also ill codepoints.
}

  asm
   test eax,eax;
   jz   @stop;
   push esi;
   xor  ecx,ecx;              // clear counter
   mov  esi,dword ptr[eax];   // sText
   mov  edx,dword ptr[esi-4]; // count of UCS4 chars
   cmp  edx,0;
   jle  @ende;
   jo   @ende;

   mov  eax,dword ptr[esi];   // load first dword, is BOM?
   cmp  eax,$FFFE0000;        // no UTF32BE
   je   @ende;
   cmp  eax,$0000FEFF;        // BOM? UTF32LE
   jne  @Load;
   add  ecx,1;                // count BOM
   sub  edx,1;
   jle  @ende;                // only BOM -> error
   add  esi,4;                // array start with BOM

align 16;
  @load:
   mov  eax,dword ptr[esi];
   add  esi,4;
   cmp  eax,$FFFF;
   ja   @go;
   add  ecx,1;
   sub  edx,1;
   jg   @Load;
   jle  @ende;
align 16;
  @go:
   cmp  eax,$10FFFF;         // ill codepoint
   ja   @error;
   add  ecx,2;
   sub  edx,1;
   jg   @Load;
   jle  @ende;

align 16;
  @error:
   add  ecx,1;
   sub  edx,1;
   jg   @load;

align 16;
  @ende:
   mov  eax,ecx;              // UTF16 chars
   pop  esi;
  @stop:
end;

{ The function convert a UTF32 coded string on a UTF16 coded string.
  Has the input string one byte order mark (BOM) this is not relevant
  and ignored. When the string has a BOM for UTF32BE the routine stop
  with error. No conversion from UTF32BE coded string is posible.
  The byte order from result string is from parameter
  OutByteOrder. The result string is saved without BOM. Ill codepoints
  on the input string is marked on result string. The function result
  is the number of UTF16 chars. (On FPC < 3.0 is the count of bytes!)
  The coding for separate LE,BE is for speed.
}
function UTF32ToUTF16(constref sUTF32 :UCS4string; pUni :Pointer;
   OutByteOrder :TByteOrder = tyLE):Longint;register;assembler;nostackframe;

{ Input:
      eax = addres of sUTF32
      edx = addres pUni Pointer
      ecx = OutByteOrder 0 = tyLE, 1 = tyBE
   Output:
      eax  = count of Unicode chars
      pUni = start addres of the converted string

   register use:
     edx = string length
     eax,ecx for convert
     esi = source addres
     edi = destination addres
     ebp = Outbyteorder, 0 = tyLE 1 = tyBE
}
 asm
   test eax,eax;
   jz   @stop;
   test edx,edx;
   jz   @stop;
   push ebp;
   push esi;
   push edi;
   push edx;                  // save the addres of pUni!
   mov  ebp,ecx;              // save ByteOrder
   mov  esi,dword ptr[eax];   // addres for sUTF32 -> [eax] for constref
   mov  edi,edx;              // addres for pUni
   mov  edx,dword ptr[esi-4]; // array quantity, d.h. quantity of chars!
   cmp  edx,0;                // is array 0?
   jle  @ende;
   jo   @ende;

   //BOM
   mov  eax,dword ptr[esi];
   cmp  eax,$FFFE0000;        // BOM UTF32BE
   je   @error;               // no UTF32BE converting
   cmp  eax,$0000FEFF;        // BOM? UTF32LE
   jne  @a1;
   sub  edx,1;                // char - 1
   jle  @error;               // only BOM -> error
   add  esi,4;                // string start with BOM
  @a1:
   cmp  ebp,0                 // 0 tyLE
   jne  @loadBE;

(* for UTF16LE *)
align 16;
  @loadLE:
   mov  eax,dword ptr[esi];   // load UTF32 Char
   add  esi,4;                // correct source pointer
   cmp  eax,$D800;
   jae  @next;
   mov  word ptr[edi],ax;
   add  edi,2;
   sub  edx,1;                // char - 1
   jg   @LoadLE;
   jle  @ende;
align 16;
  @next:
   cmp  eax,$DFFF;            // values from D800 - DFFF is ill!
   jbe  @foultcodingLE;
   cmp  eax,$FFFF;
   ja   @surroLE;
   mov  word ptr[edi],ax;
   add  edi,2;
   sub  edx,1;
   jg   @LoadLE;
   jle  @ende;

align 16;
  @surroLE:                     // need 2 words
   cmp  eax,$10FFFF;
   ja   @foultcodingLE;         // invalid codepoint
   sub  eax,$10000;
   mov  ecx,eax;
   shr  ecx,10;
   add  ecx,$D800;
   mov  word ptr[edi],cx;
   add  edi,2;
   and  eax,$000003FF;
   add  eax,$DC00;
   mov  word ptr[edi],ax;
   add  edi,2;
   sub  edx,1;                // subtract length
   jg   @LoadLE;
   jle  @ende;

align 16;
  @foultcodingLE:
   mov  word ptr[edi],$FFFD;  // error mark
   add  edi,2;
   sub  edx,1;
   jg   @LoadLE;
   jle  @ende;

(* for UTF16BE *)
align 16;
  @loadBE:
   mov  eax,dword ptr[esi];   // load UTF32 Char
   add  esi,4;                // correct source pointer
   cmp  eax,$0000FDFF;        // error mark UTF32LE
   je   @foultcodingBE;
   cmp  eax,$D800;
   jae  @nextBE;
   xchg al,ah;
   mov  word ptr[edi],ax;
   add  edi,2;
   sub  edx,1;
   jg   @LoadBE;
   jle  @ende;
align 16;
  @nextBE:
   cmp  eax,$DFFF;            // values from D800 - DFFF is ill!
   jbe  @foultcodingBE;
   cmp  eax,$FFFF;
   ja   @surroBE;
   xchg al,ah;
   mov  word ptr[edi],ax;
   add  edi,2;
   sub  edx,1;
   jg   @LoadBE;
   jle  @ende;

align 16;
  @surroBE:                     // need 2 words
   cmp  eax,$10FFFF;
   ja   @foultcodingBE;         // invalid codepoint
   sub  eax,$10000;
   mov  ecx,eax;
   shr  ecx,10;
   add  ecx,$D800;
   xchg cl,ch;
   mov  word ptr[edi],cx;
   add  edi,2;
   and  eax,$000003FF;
   add  eax,$DC00;
   xchg al,ah;
   mov  word ptr[edi],ax;
   add  edi,2;
   sub  edx,1;                // subtract length
   jg   @LoadBE;
   jle  @ende;

align 16;
  @foultcodingBE:
   mov  word ptr[edi],$FDFF;  // error mark
   add  edi,2;
   sub  edx,1;
   jg   @LoadBE;

align 16;
  @error:
   pop  edx;                  // addres of pUni
   xor  eax,eax;              // Nul
   jz   @go;

align 16;
  @ende:
   xor  eax,eax;
   mov  word ptr[edi],ax;     // Nul char
   pop  edx;                  // addres of pUni
   sub  edi,edx;              // compute the bytes
   mov  eax,edi;
   shr  eax,1;                // quantity of chars
  @go:
   pop  edi;
   pop  esi;
   pop  ebp;
  @stop:
 end;

{ The function convert a UTF32 coded string on a UTF8 coded string.
  A BOM on start of input string is ignored. When see the UTF32BOM the
  routine stop with error. No convert for UTF32BE coded string is posible.
  Ill codepoints on input string is marked on result string. The result
  string is saved without BOM. The function result is the number of bytes.
}
function UTF32ToUTF8(constref sUTF32 :UCS4string; pUTF8 :Pointer):Longint;
      register;assembler;nostackframe;

{ Input:
      eax = pointer of sUCS4 addres
      edx = addres pUTF8 Pointer
   Output:
      eax = string length on bytes
      pUTF8 = addres of converted string

   register use:
     edx = string length
     eax,ecx for convert
     esi = source addres
     edi = destination addres
}
 asm
   test eax,eax;
   je   @stop;
   test edx,edx;
   je   @stop;
   push esi;
   push edi;
   push edx;                  // save the addres of pUni
   mov  esi,dword ptr[eax];   // addres for sUTF32 for constref -> [eax]
   mov  edi,edx;              // addres for pUni
   xor  eax,eax;              // clear result
   mov  edx,dword ptr[esi-4]; // UTF32 string length on chars
   cmp  edx,0;
   jle  @ende;
   jo   @ende;

   //BOM
   mov  eax,dword ptr[esi];
   cmp  eax,$FFFE0000;        // UTF32BE
   je   @error;               // no UTF32BE
   cmp  eax,$0000FEFF;        // UTF32LE
   jne  @load;
   sub  edx,1;                // array length - 1
   jle  @error;               // only BOM -> error
   add  esi,4;                // string start with BOM

align 16;
  @load:
   mov  eax,dword ptr[esi];   // UTF32 Char
   add  esi,4;                // correct source pointer
   mov  ecx,eax;              // save value for lather
   cmp  ecx,$80;
   jb   @Start1;              // convert to 1 byte
   cmp  ecx,$800;
   jb   @Start2;              // convert to 2 byte
   cmp  ecx,$D800;
   jb   @Start3;              // convert to 3 byte
   cmp  ecx,$DFFF
   jbe  @foultcoding;         // D800...DFFF surro range
   cmp  ecx,$10000;
   jb   @Start3;              // convert to 3 byte

  // @Start4:
   cmp  ecx,$10FFFF;
   ja   @foultcoding;         // invalid codepoint
   shr  ecx,18;               // convert first byte
   or   ecx,$000000F0;
   mov  byte ptr[edi],cl;
   add  edi,1;
   mov  ecx,eax;              // second byte
   shr  ecx,12;
   and  ecx,$0000003F;
   or   ecx,$00000080;
   mov  byte ptr[edi],cl;
   add  edi,1;
   mov  ecx,eax;              // byte 3
   shr  ecx,6;
   and  ecx,$0000003F;
   or   ecx,$00000080;
   mov  byte ptr[edi],cl;
   add  edi,1;
   and  eax,$0000003F;        // byte 4
   or   eax,$00000080;
   mov  byte ptr[edi],al;
   add  edi,1;
   sub  edx,1;                // subtract length
   jg   @Load;
   jle  @ende;

align 16;
  @Start1:
   mov  byte ptr[edi],al;
   add  edi,1;
   sub  edx,1;
   jg   @Load;
   jle  @ende;

align 16;
  @Start2:
   shr  ecx,6;                // first byte
   or   ecx,$000000C0;
   mov  byte ptr[edi],cl;
   add  edi,1;
   and  eax,$0000003F;        // second byte
   or   eax,$00000080;
   mov  byte ptr[edi],al;
   add  edi,1;
   sub  edx,1;
   jg   @Load;
   jle  @ende;

align 16;
  @Start3:
   shr  ecx,12;               // first byte
   or   ecx,$0000E0;
   mov  byte ptr[edi],cl;
   add  edi,1;
   mov  ecx,eax;              // second byte
   shr  ecx,6;
   and  ecx,$0000003F;
   or   ecx,$00000080;
   mov  byte ptr[edi],cl;
   add  edi,1;
   and  eax,$0000003F;        // byte 3
   or   eax,$00000080;
   mov  byte ptr[edi],al;
   add  edi,1;
   sub  edx,1;
   jg   @Load;
   jle  @ende;

align 16;
  @foultcoding:
   mov  dword ptr[edi],$BDBFEF;
   add  edi,3;
   sub  edx,1
   jg   @Load;
   jle  @ende;

align 16;
  @error:
   pop  edx;
   xor  eax,eax;              // Nul Byte
   jmp  @go;

align 16;
  @ende:
   pop  edx;
   mov  byte ptr[edi],$0      // Nul byte
   sub  edi,edx;
   mov  eax,edi;              // Size on byte
  @go:
   pop  edi;
   pop  esi;
  @stop:
 end;

{ Test for minimal CPU 80486 or newly prozessor. I use the BSWAP on coding
  and this is only from 80486 and above. When exist CPUID then Pentium
   or above }
function fnTestMinCPU80486 :Boolean;assembler;nostackframe;
 asm
   push ecx;
   pushfd;
   pushfd;
   pop  eax;                // load eflags
   mov  ecx,eax;            // save the old eflags
   xor  eax,$00200000;      // toogle Bit 21 in eflags; exist CPUID ?
   push eax;
   popfd;                   // set the new eflags
   pushfd;                  // load the eflags new
   pop  eax;
   xor  eax,ecx;
   jnz  @ok
  @test_486:
   // test for 80486; is posible set AC-bit (Bit 18) on EFLAGS?
   pop  eax;                  // load the original eflag
   push eax;
   mov  ecx,eax;
   xor  eax,$00400000;        // toogle AC-Bit on EFLAGS
   push eax;
   popfd;
   pushfd;
   pop  eax;
   xor  eax,ecx;
   jnz  @ok;
  @not_ok:
   xor  eax,eax;
   jmp  @go;
  @ok:
   mov  eax,1;
  @go:
   popfd;
   pop ecx;
end;

(*--------------------------Pascal------------------------------------------*)

{The system setcodepage routine has a many overhead}
{$IFDEF FPC_HAS_CPSTRING}
procedure fnSetCodepage(p :Pointer; NewCodepage :word);
begin
  if p <> nil then begin
    p := Pointer(p^); // real addres
    {$IFDEF CPU64}
    p := p - 24;
    {$ENDIF}
    {$IFDEF CPU32}
    p := p - 12;
    {$ENDIF}
    {$IFDEF CPU16}
      {$FATAL not definined}
    {$ENDIF}
    if p <> nil then
     word(p^) := NewCodePage;
  end;
end;
{$endif}


{$IFDEF FPC_HAS_CPSTRING}
function fnUTF8ToUTF16(const sText :RawBytestring;
                      OutByteOrder :TByteorder = tyLE):Unicodestring;register;
{$ELSE}
function fnUTF8ToUTF16(const sText :string;
                      OutByteOrder :TByteorder = tyLE):Unicodestring;register;
{$ENDIF}
 var
   lChar16 :Longint;

(* The system routine think each UTF8 byte is converting to one
   UTF16 char (valid when only ASCII chars). That is rapid, but
   reserve memory witch real not needed.
   Therefore we count the result chars for the UTF16 string and so
   we need less memory. Yes cost run time for scan.
   Remark:
    - when OutbyteOrder is tyBE, then you can not use Freepascal for working
      with this result string. This is only for file transfer for working
      systems with diffrent byte order in memory p.e MIPS,IBM *)
 begin
  Result := '';
  if sText <> '' then begin
    (* quantity of UTF16 chars, it is diffrent from count UTF8Chars
       UTF16 can have surrogate (all 4byte UTF8chars) *)
    lChar16 := UTF8ToUTF16Length(sText);
    if lChar16 > 0 then begin
      SetLength(Result,lChar16);
      lChar16 := UTF8ToUTF16(sText,Pointer(Result),OutByteOrder);
      if lChar16 > 0 then begin
        SetLength(Result,lChar16);
        {$IFDEF FPC_HAS_CPSTRING}
          if OutByteorder = tyBE then
            // not code conversion use separate coding
            fnSetCodePage(@Result,12001);
        {$endif}
      end
      else
        Result := '';
    end;
  end;
end;


{$IFDEF FPC_HAS_CPSTRING}
function fnUTF8ToUTF32(const sText :Rawbytestring):UCS4String;register;
{$ELSE}
function fnUTF8ToUTF32(const sText :string):UCS4String;register;
{$ENDIF}
 var
   lChars :Longint;

begin
  Result := nil;
  if sText <> '' then begin
    // quantity of UTF8 chars
    lChars := fnUTF8Length(sText);
    if lChars > 0 then begin
      SetLength(Result,lChars);
      lChars := UTF8ToUTF32(sText,Pointer(Result));
      if lChars > 0 then begin
        SetLength(Result,lChars);
      end
      else
       Result := nil;
    end;
  end;
end;

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF16ToUTF8(const sText :Unicodestring;
                      InByteOrder :TByteOrder = tyLE):Rawbytestring;register;
{$ELSE}
function fnUTF16ToUTF8(const sText :Unicodestring;
                      InByteOrder :TByteOrder = tyLE):string;register;
{$ENDIF}

 var
   lByte  :Longint;

 begin
   Result := '';
   if sText <> '' then begin
     SetLength(Result,Length(sText)*3);
     lByte := UTF16ToUTF8(sText,Pointer(Result),InByteOrder);
     if lByte > 0 then begin
       SetLength(Result,lByte);
       {$IFDEF FPC_HAS_CPSTRING}
       fnSetCodePage(@Result,65001);  //UTF8string
       {$endif}
     end
     else
       Result := '';
  end;
end;

function fnUTF16ToUTF32(const sText :UnicodeString;
                       InByteOrder :TByteOrder = tyLE):UCS4String;register;
 var
   lChar32 :Longint;

begin
  Result := nil;
  if sText <> '' then begin
    SetLength(Result,Length(sText));
    lChar32 := UTF16ToUTF32(sText,Pointer(Result),InByteOrder);
    if lChar32 > 0 then
      SetLength(Result,lChar32)
    else
     Result := nil;
  end;
end;

function fnUTF32ToUTF16(constref sText :UCS4String;
                       OutByteOrder :TByteOrder = tyLE):UnicodeString;register;
var
 lChar16 :Longint;

begin
  Result := '';
  if Assigned(sText) then begin
    lchar16 := UTF32toUTF16Length(sText);
    if lChar16 > 0 then begin
      SetLength(Result,lChar16);
      lChar16 := UTF32ToUTF16(sText,Pointer(Result),OutByteOrder);
      if lChar16 > 0 then begin
        SetLength(Result,lChar16);
        {$IFDEF FPC_HAS_CPSTRING}
         if OutByteOrder = tyBE then
           fnSetCodePage(@Result,12001);
        {$endif}
      end
      else
        Result := '';
    end;
  end;
end;

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF32ToUTF8(constref sText :UCS4String):Rawbytestring;register;
{$ELSE}
function fnUTF32ToUTF8(constref sText :UCS4String):string;register;
{$ENDIF}

 var
  lByte  :Longint;

begin
  Result := '';
  if Assigned(sText) then begin
    lByte := UTF32ToUTF8Length(sText);
    if lByte > 0 then begin
      SetLength(Result,lByte);
      lByte := UTF32ToUTF8(sText,Pointer(Result));
      if lByte > 0 then begin
        SetLength(Result,lByte);
        {$IFDEF FPC_HAS_CPSTRING}
        fnSetCodePage(@Result,65001);
        {$endif}
      end
      else
        Result := '';
   end;
  end;
end;

initialization
 (* Test for min. CPU 80486 or newly procesor *)
 if not fnTestMinCPU80486 then
   RunError(65530);

{$ENDIF CPU386}

end.

