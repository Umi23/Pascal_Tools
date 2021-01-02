{********************************************************

 source file      : UniW64.pas
 typ              : Pascal Unit
 creation date    : 2017-05-17
 compiler version : FPC 2.6.4/FPC 3.0.4
 system           : Windows 7 64-bit
 last revision    : 2020-12-23 with FPC 3.2
 header           : Unicode convert functions in
                    Assembler for 64-bit Intel
                    or AMD processors.

 Copyright (c) 2019 - 2021 Klaus Stöhr
 e-mail           k.stoehr@gmx.de
 
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
 You should have received a copy of the GNU Lesser General
 Public License along with this program. If not,          
 see <https://www.gnu.org/licenses/>.                     
********************************************************}
unit UniW64;
{$mode objfpc}{$H+}
{$ASMMODE INTEL}
{$CODEPAGE UTF8}
{$OPTIMIZATION OFF} // no compiler optimization; assembler is optimized

interface

{$IFDEF CPUX86_64}
{ The unit only support the official FPU releases >= 2.6 .
  All functions start with a 'fn' on name. This is for difference
  better diffrent with homonomous names.
}
type
  TByteOrder = (tyLE,tyBE);

{ byte order on memory tyLE = low order (Intel) processor
                       tyBE = high order (MIPS et.al.)
}
{$IFDEF FPC_HAS_CPSTRING}
{UTF8}
function fnUTF8Length(const sText :Rawbytestring):Int64;
function fnUTF8ToUTF16(const sText :Rawbytestring;
                      OutByteOrder :TByteorder = tyLE):Unicodestring;
function fnUTF8ToUTF32(const sText :Rawbytestring):UCS4String;

{UTF16}
function fnUTF16ToUTF8(const sText :Unicodestring;
                      InByteOrder :TByteOrder = tyLE):Rawbytestring;
function fnUTF16ToUTF32(const sText :UnicodeString;
                      InByteOrder :TByteOrder = tyLE):UCS4String;
{UTF32}
function fnUTF32ToUTF8(constref sText :UCS4String):Rawbytestring;
function fnUTF32ToUTF16(constref sText :UCS4String;
                      OutByteOrder :TByteOrder = tyLE):UnicodeString;
{$ELSE}
{UTF8}
function fnUTF8Length(const sText :string):Int64;
function fnUTF8ToUTF16(const sText :string;
                      OutByteOrder :TByteorder = tyLE):Unicodestring;
function fnUTF8ToUTF32(const sText :string):UCS4String;

{UTF16}
function fnUTF16ToUTF8(const sText :Unicodestring;
                      InByteOrder :TByteOrder = tyLE):string;
function fnUTF16ToUTF32(const sText :UnicodeString;
                      InByteOrder :TByteOrder = tyLE):UCS4String;

{UTF32}
function fnUTF32ToUTF8(constref sText :UCS4String):string;
function fnUTF32ToUTF16(constref sText :UCS4String;
                      OutByteOrder :TByteOrder = tyLE):UnicodeString;
{$ENDIF FPC_HAS_CPSTRING}
{$ENDIF CPUX86_64}

implementation

{$IFDEF CPUX86_64}
{Remark: Why byte order?
         Its posible that we receive a file with other coding sequenz
         (tyBE) and so that we need a convert for use on windows. Also
         could be the other fall, we need for data exchange with other
         operating system a convert. (tyLE -> tyBE)
         UTF32 will only use on computer internal and not common for change
         data with other operating systems. Windows use tyLE and so need no
         other byte order.

         I have only taken standard commands for all procesors from
         80486 and higher. Many assembler sequence on follow code is for
         speed.
         One BOM (byte order mark) on UTF8 encoded strings is not recommended
         and we ignoring on convert.
         See Unicode Standard 10 (or higher) Part 3.10 unicode convert schemas!

         Follow the UNICODE standard, ill codepoints on source are changed
         to U+FFFD on result string.

         For UTF8    -> $EFBFBD
             UTF16LE -> $FDFF
             UTF16BE -> $FFFD
             UTF32LE -> $FDFF0000
             UTF32BE -> $0000FFFD
}
(*-------------------Assembler----------------------------------------*)

{Here the ABI for Integer,Boolan,Pointer}

{ The ABI for Windows 64-bit
  Integer:
    return value on register rax

    Input values
      first  in rcx
      second in rdx
      third  in r8
      four   in r9
      the rest on stack from left to rigth
    rsi,rdi,rbx,rsp,rbp,r12..r15 must saved
    the rest is free use on routine

 The ABI Linux,Unix,Mac
  Integer:
    return value on register rax and rdx

    Input values
      first  in rdi
      second in rsi
      third  in rdx
      four   in rcx
      five   in r8
      six    in r9
      the rest on stack from left to rigth

      rbx,rsp,rbp,r12..r14 must save
      the rest ist free use on routine
}

{ The result of the function is the number of UTF8 chars on sText. Ill
  code points will count on order the unicode standard (see Unicode 11.0 or
  higher, part 3.9 page 129 table 3-8 row 2.) The exist Lazarus function
  UTF8length count evry ill code point we on table 3-8 row 3.
}

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF8Length(const sText :Rawbytestring):Int64;
         assembler;nostackframe;
{$ELSE}
function fnUTF8Length(const sText :string):Int64;
         assembler;nostackframe;
{$ENDIF}

{ Input:
    rcx = addres sText

   Output:
    rax = count on UTF8chars

   use the register:
    r8  = address sText
    r9  = error counter;
    r10 = string length
    rax,r11

   Remark: The load of 4 byte for test BOM is ok, a string have a Nul byte
           at the end.
}

asm
  xor  rax,rax;
 {$ifndef WIN64}
  mov rcx,rdi:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  {$IFDEF FPC_HAS_CPSTRING}
  (* description: test it's a real UTF8 string *)
  movzx edx,word ptr[rcx-24];
  cmp  edx,65001;            // if UTF8string?
  jne  @stop;
  {$endif}
  mov  r10,qword ptr[rcx-8]; // string length
  cmp  r10,0;
  jle  @stop;
  jo   @stop;                // we have SIGNED value
  mov  r8,rcx;               // adress sText
  xor  r9,r9;

  cmp  r10,3;                // if BOM possibility?
  jl   @Load;                // no, when < 3
  mov  eax,dword ptr[r8];    // load 4 byte from sText
  and  eax,$00FFFFFF;        // only 3 byte test
  cmp  eax,$00BFBBEF;        // UTF8 BOM?
  jne  @Load;
  add  r9,1;                 // cont BOM
  add  r8,3;                 // yes, correct the source Pointer
  sub  r10,3;                // and length of string; only BOM -> ende
  jle  @ende;

align 16;
 @load:
  mov  al,byte ptr[r8];      // load start byte for test
  cmp  al,$80;               // ASCII code?
  jb   @start1;              // yes, 1 Byte
  cmp  al,$C2;               // value $80...$C1 can not be at start of sequence
  jb   @foultcoding;
  cmp  al,$DF;               // 2 byte
  jbe  @start2;
  cmp  al,$EF;               // 3 byte
  jbe  @start3;
  cmp  al,$F4;               // 4 byte
  jbe  @start4;
  ja   @foultcoding;         // error coding

align 16
 @start1:
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @load;
  jle  @Ende;

align 16;
 @Start2:
  cmp  r10,2;
  jl   @foultcoding;
  movzx eax,word ptr[r8];
  bswap eax;
  mov  r11d,eax;
  and  r11d,$E0C00000;        // test of conform
  cmp  r11d,$C0800000;        // 110xxxxx 10xxxxxx
  jne  @foult2;
  cmp  eax, $C2800000;        // min value for 2 byte sequence
  jb   @foult2;
  cmp  eax, $DFBF0000;        // max value for 2 byte sequence
  ja   @foult2;
  add  r8,2;                  // source pointer
  add  r9,1;                  // error count
  sub  r10,2;                 // string length - 2
  jg   @Load;
  jle  @Ende;

align 16;
 @foult2:
  bswap eax;                  // correct byte order for follow tests
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jle  @ende;
  cmp  ah,$80;               // is a Start byte?
  jb   @Load;
  cmp  ah,$C2;               // dito
  jae  @Load;
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start3:
  cmp  r10,3;
  jl   @foult30;
  mov  eax,dword ptr[r8];    // load 4 Byte
  and  eax,$00FFFFFF;        // only 3 byte
  bswap eax;
  mov  r11d,eax;
  and  r11d,$F0C0C000;       // test for conform
  cmp  r11d,$E0808000;       // 1110xxxx 10xxxxxx 10xxxxxx
  jne  @foult3;              // not conform -> error
  cmp  eax, $E0A08000;       // min value for 3 byte sequence
  jb   @foult3;
  cmp  eax, $EFBFBF00;       // max value for 3 byte sequence
  ja   @foult3;
  cmp  eax, $ED9FBF00;
  ja   @test31;
  add  r8,3;
  add  r9,1;
  sub  r10,3;
  jg   @Load;
  jle  @Ende;

align 16;
 @test31:                    // special test
  cmp  eax,$EE808000;        // when < surrogate range
  jb   @foult3;
  add  r8,3;
  add  r9,1;
  sub  r10,3;
  jg   @load;
  jle  @ende;

align 16;
 @foult30:
  cmp r10,2;
  je  @error2;
  add r9,1;
  jmp @ende;
 @error2:
  movzx eax,word ptr [r8];
  bswap eax;

align 16;
 @foult3:
  mov  r11d,2;            // count for follow test
  bswap eax;
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jle  @ende;
  cmp  al,$E0;
  je   @E0;
  cmp  al,$ED;
  je   @ED;
align 16;
 @1:
  cmp  r10,0;
  jle  @ende;
  cmp  r11d,0;
  jle  @Load;
  shr  eax,8;        // byte in ah -> al
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r8,1;
  sub  r10,1;
  sub  r11d,1;
  cmp  al,$BF;
  jbe  @1;
  add  r9,1;
  jmp  @1;
align 16;
 @E0:
  cmp  ah,$A0;
  jae  @1;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
align 16;
 @ED:
  cmp  ah,$9F;
  jbe  @1;
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @Start4:
  cmp  r10,4
  jl   @foult40;
  mov  eax,dword ptr [r8];
  bswap eax;
  mov  r11d,eax;
  and  r11d,$F8C0C0C0;        // test the bytes for conform
  cmp  r11d,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;               // when not -> error
  cmp  eax, $F0908080;        // min value for 4 byte sequence
  jb   @foult4;               // < error
  cmp  eax, $F48FBFBF;        // max value for 4 Byte sequence
  ja   @foult4;               // > error
  add  r8,4;
  add  r9,1;
  sub  r10,4;
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp r10,3;
  je  @err3;
  cmp r10,2;
  je  @err2;
  add r9,1;
  jmp @ende;
 @err3:
  mov eax,dword ptr [r8];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [r8];
  bswap eax;

align 16;
 @foult4:
  mov  r11d,3;
  bswap eax;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  r10,0;
  jle  @ende;
  cmp  r11d,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r8,1;
  sub  r10,1;
  sub  r11d,1;
  cmp  al,$BF;
  jbe  @a;
  add  r9,1;
  jmp  @a;
align 16;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
align 16;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @load;

align 16;
 @ende:
  mov  rax,r9;
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;

{See fnUTF8Length, only count chars needed for UTF16 convert.}
{$IFDEF FPC_HAS_CPSTRING}
function UTF8ToUTF16Length(const sText :Rawbytestring):Int64;
         assembler;nostackframe;
{$ELSE}
function UTF8ToUTf16Length(const sText :string):Int64;
         assembler;nostackframe;
{$ENDIF}

{ Input:
    rcx = addres sText

   Output:
    rax = count on UTF8chars

   use the register:
    r8  = address sText
    r9  = error counter;
    r10 = string length
    rax,r11

   Remark: The load of 4 byte for test BOM is ok, a string have a Nul byte
           at the end.
}

asm
  xor  rax,rax;
 {$ifndef WIN64}
  mov rcx,rdi:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  {$IFDEF FPC_HAS_CPSTRING}
  (* description: test it's a real UTF8 string *)
  movzx edx,word ptr[rcx-24];
  cmp  edx,65001;            // if UTF8string?
  jne  @stop;
  {$endif}
  mov  r10,qword ptr[rcx-8]; // string length
  cmp  r10,0;
  jle  @stop;
  jo   @stop;                // we have SIGNED value
  mov  r8,rcx;               // adress sText
  xor  r9,r9;

  cmp  r10,3;                // if BOM possibility?
  jl   @Load;                // no, when < 3
  mov  eax,dword ptr[rsi];   // load 4 byte from sText
  and  eax,$00FFFFFF;        // only 3 byte test
  cmp  eax,$00BFBBEF;        // UTF8 BOM?
  jne  @Load;
  add  r9,1;                 // count BOM
  add  r8,3;                 // yes, correct the source Pointer
  sub  r10,3;                // and length of string; only BOM -> ende
  jle  @ende;

align 16;
 @load:
  mov  al,byte ptr[r8];      // load start byte for test
  cmp  al,$80;               // ASCII code?
  jb   @start1;              // yes, 1 Byte
  cmp  al,$C2;               // value $80...$C1 can not be at start of sequence
  jb   @foultcoding;
  cmp  al,$DF;               // 2 byte
  jbe  @start2;
  cmp  al,$EF;               // 3 byte
  jbe  @start3;
  cmp  al,$F4;               // 4 byte
  jbe  @start4;
  ja   @foultcoding;         // error coding

align 16
 @start1:
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @load;
  jle  @Ende;

align 16;
 @Start2:
  cmp  r10,2;
  jl   @foultcoding;
  movzx eax,word ptr[r8];
  bswap eax;
  mov  r11d,eax;
  and  r11d,$E0C00000;        // test of conform
  cmp  r11d,$C0800000;         // 110xxxxx 10xxxxxx
  jne  @foult2;
  cmp  eax, $C2800000;        // min value for 2 byte sequence
  jb   @foult2;
  cmp  eax, $DFBF0000;        // max value for 2 byte sequence
  ja   @foult2;
  add  r8,2;
  add  r9,1;
  sub  r10,2;
  jg   @Load;
  jle  @Ende;

align 16;
 @foult2:
  bswap eax;
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jle  @ende;
  cmp  ah,$80;
  jb   @Load;
  cmp  ah,$C2;     // see a start byte?
  jae  @Load;
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start3:
  cmp  r10,3;
  jl   @foult30;
  mov  eax,dword ptr[r8];    // load 4 Byte
  and  eax,$00FFFFFF;        // only 3 byte
  bswap eax;
  mov  r11d,eax;
  and  r11d,$F0C0C000;       // test for conform
  cmp  r11d,$E0808000;       // 1110xxxx 10xxxxxx 10xxxxxx
  jne  @foult3;              // not conform -> error
  cmp  eax, $E0A08000;       // min value for 3 byte sequence
  jb   @foult3;
  cmp  eax, $EFBFBF00;       // max value for 3 byte sequence
  ja   @foult3;
  cmp  eax, $ED9FBF00;
  ja   @test31;
  add  r8,3;
  add  r9,1;
  sub  r10,3;
  jg   @Load;
  jle  @Ende;

align 16;
 @test31:                     // special test
  cmp  eax,$EE808000;
  jb   @foult3;               // when < surrogate range
  add  r8,3;
  add  r9,1;
  sub  r10,3;                 // only 3 bytes
  jg   @load;
  jle  @ende;

align 16;
 @foult30:
  cmp r10,2;
  je  @error2;
  add r9,1;
  jmp @ende;
 @error2:
  movzx eax,word ptr [r8];
  bswap eax;

align 16;
 @foult3:
  mov  r11d,2;              // max count for test
  bswap eax;
  add  r9,1;                // error count
  add  r8,1;                // source pointer
  sub  r10,1;
  jle  @ende;
  cmp  al,$E0;              // test start byte
  je   @E0;
  cmp  al,$ED;              // dito
  je   @ED;
align 16;
 @1:
  cmp  r10,0;
  jle  @ende;
  cmp  r11d,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r8,1;
  sub  r10,1;
  sub  r11d,1;
  cmp  al,$BF;
  jbe  @1;
  add  r9,1;
  jmp  @1;
 @E0:
  cmp  ah,$A0;
  jae  @1;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
 @ED:
  cmp  ah,$9F;
  jbe  @1;
  add  r9,1;
  add  r8,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @Start4:
  cmp  r10,4
  jl   @foult40;
  mov  eax,dword ptr [r8];
  bswap eax;
  mov  r11d,eax;
  and  r11d,$F8C0C0C0;        // test the bytes for conform
  cmp  r11d,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;               // when not -> error
  cmp  eax, $F0908080;        // min value for 4 byte sequence
  jb   @foult4;               // < error
  cmp  eax, $F48FBFBF;        // max value for 4 Byte sequence
  ja   @foult4;               // > error
  add  r8,4;
  add  r9,2;                  // we need 2 UTF16 codepoints (surrogate)
  sub  r10,4;
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp r10,3;
  je  @err3;
  cmp r10,2;
  je  @err2;
  add r9,1;              //only 1 byte
  jmp @ende;
 @err3:
  mov eax,dword ptr [r8];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [r8];
  bswap eax;

align 16;
 @foult4:
  mov  r11d,3;
  bswap eax;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  r10,0;
  jle  @ende;
  cmp  r11d,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r8,1;
  sub  r10,1;
  sub  r11d,1;
  cmp  al,$BF;
  jbe  @a;
  add  r9,1;
  jmp  @a;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:
  add  r8,1;
  add  r9,1;
  sub  r10,1;
  jg   @load;

align 16;
 @ende:
  mov  rax,r9;
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;

{Intern use}
procedure error_1;assembler;nostackframe;
asm
  test r8b,r8b;
  jnz  @next;
  mov  word ptr[r11],$FFFD;  // error mark UTF16LE
  add  r11,2;
  ret;
 @next:                      // UTF16BE
  mov  word ptr[r11],$FDFF;  // error mark UTF16BE
  add  r11,2;
end;

{The function convert a UTF8 encoded string on a UTF16 encoded string.
 The result string will saved without BOM. The input parameter
 OutByteOrder give the byte order of the result string. The function
 check for correct input string coding. Ill codepoints is marked on result
 string. The function result is the number of UTF16 chars.
}
{$IFDEF FPC_HAS_CPSTRING}
function UTF8ToUTF16(const sText :Rawbytestring; pUTF16Char :Pointer;
   OutByteOrder :TByteOrder):Int64;assembler;nostackframe;
{$else}
function UTF8ToUTF16(const sText :string ;pUTF16Char :Pointer;
   OutByteOrder :TByteOrder):Int64;assembler;nostackframe;
{$endif}

{ Input:  for win64
    rcx = addres sText
    rdx = addres pUTF16Char
    r8  = ByteOrder  (0 = tyLE(Intel), 1 = tyBE)

   Output:
     rax = count of UTF16 chars
     rdx = adress pUTF16Char
     rsi = adress pUTF16Char for <> Win64

   use registers:
    r8  = ByteOrder;
    r9  = adress sText
    r10 = sText length
    r11 = addres lpUnicodechar
    rax,rcx,rdx for convert
}

asm
  xor  rax,rax;              // set result on case of invalid input
 {$ifndef WIN64}
  mov rcx,rdi:
  mov rdx,rsi:
  mov r8, rdx:
  mov r9, rcx:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  test rdx,rdx;
  jz   @stop;
  {$IFDEF FPC_HAS_CPSTRING}
  (* description: test it's a real UTF8 string *)
  movzx r9,word ptr[rcx-24];
  cmp  r9,65001;            // if UTF8string?
  jne  @stop;
  {$endif}
  mov  r10,qword ptr[rcx-8]; // UTF8string length
  cmp  r10,0;
  jle  @stop;
  jo   @stop;

  push rcx;                 // save start adress
  push rdx;
  mov  r9, rcx;             // addres sText
  mov  r11,rdx;             // adress lpUnicodechar

  cmp  r10,3;               // if BOM possibility?
  jl   @Load;               // no, when < 3
  mov  eax,dword ptr[r9];   // load 4 byte from sText
  and  eax,$00FFFFFF;       // only 3 byte test
  cmp  eax,$00BFBBEF;       // UTF8 BOM?
  jne  @Load;
  add  r9,3;                // yes, correct the source Pointer
  sub  r10,3;               // and length of string
  jle  @ende;

align 16;
 @Load:
  mov  al,byte ptr[r9];     // load start byte for test
  cmp  al,$80;              // ASCII code?
  jb   @Start1;             // yes, 1 Byte
  cmp  al,$C2;              // $80...$C1 is not a valid start point
  jb   @foultcoding;
  cmp  al,$DF;              // 2 byte sequenz
  jbe  @start2;
  cmp  al,$EF;              // 3 byte sequence
  jbe  @start3;
  cmp  al,$F4;              // 4 byte sequence
  jbe  @start4;
  ja   @foultcoding;        // no valid start byte -> error

align 16;
 @start1:                    // we found 1 Byte sequence
  and  eax,$000000FF;        // clear upper bytes
  test r8b,r8b;              // 0 = tyLE
  jnz  @step11;              // coding for speed tyLE
  mov  word ptr[r11],ax;     // save the word
  add  r11,2;                // add destination pointer + 2
  add  r9,1;                 // add source pointer + 1
  sub  r10,1;                // string length - 1
  jg   @Load;
  jle  @ende;                // next byte
 @step11:
  xchg al,ah;                // byte order tyBE
  mov  word ptr[r11],ax;     // save the word
  add  r11,2;                // add destination pointer + 2
  add  r9,1;                 // add source pointer + 1
  sub  r10,1;                // string length - 1
  jg   @Load;
  jle  @ende;                // next byte

align 16;
 @start2:
  cmp  r10,2;                // string length >= 2 byte?
  jl   @foultcoding;
  movzx eax,word ptr[r9];   // load the 2 byte sequence
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
  and  eax,$00003F1F;        // and the first word Byte 1F second byte with 3F
  xor  ecx,ecx;              // clear
  mov  cl,al;
  shl  cl,6;                 // first byte shl 6
  shr  eax,8;                // second byte -> al
  or   eax,ecx;              // result is UTF16 coding
  test r8b,r8b;              // 0 = tyLE
  jnz  @step21;              // following construct speed for tyLE
  mov  word ptr[r11],ax;     // save the result
  add  r11,2;                // destination pointer + 2
  add  r9,2;                 // add source pointer + 2
  sub  r10,2;                // string length - 2
  jg   @Load;
  jle  @ende;
 @step21:
  xchg al,ah;                // correct the byte order (UTF16BE)
  mov  word ptr[r11],ax;     // save the result
  add  r11,2;                // destination pointer + 2
  add  r9,2;                 // add source pointer + 2
  sub  r10,2;                // string length - 2
  jg   @Load;
  jle  @ende;

align 16;
 @foult2:
  bswap eax;                // correct the byte order
  add  r9,1;                // add source pointer
  call error_1;             // set error in result string
  sub  r10,1;
  jle  @ende;
  cmp  ah,$80;              // is the follow byte a start byte?
  jb   @Load;
  cmp  ah,$C2;              // dito
  jae  @Load;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

  //remark: when only 3 byte at the end no error, the string have a
  //        implicit Nul Byte at the end
align 16;
 @start3:                    // found a 3 byte sequence
  cmp  r10,3                 // string length >= 3 byte
  jl   @foult30;
  mov  eax,dword ptr[r9];    // load 4 Byte
  and  eax,$00FFFFFF;        // clear byte 4, only 3 byte
  bswap eax;
  mov  ecx,eax;              // load the saved value
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
  bswap eax;                 // correct the byte order
  and  eax,$003F3F0F;        // here all and's for the bytes
  xor  edx,edx;              // clear edx
  xor  ecx,ecx;              // clear ecx
  mov  dl,al;                // 1 Byte and 0F shl 12
  shl  edx,12;
  mov  cl,ah;                // 2 Byte and 3F shl 6
  shl  ecx,6;
  or   edx,ecx;              // inter result
  shr  eax,16;               // 3 Byte -> al and 3F
  or   eax,edx;              // result UTF16 coding
  add  r9,3;                 // add source pointer + 3
  test r8b,r8b;              // 0 = tyLE
  jnz  @step32;              // coding for speed tyLE
  mov  word ptr[r11],ax;     // save the word
  add  r11,2;                // destination pointer + 2
  sub  r10,3;                // string length - 3
  jg   @Load;
  jle  @ende;
align 16;
 @step32:
  xchg al,ah;                // correct the byte order (UTF16BE)
  mov  word ptr[r11],ax;     // save the word
  add  r11,2;                // destination pointer + 2
  sub  r10,3;                // string length - 3
  jg   @Load;
  jle  @ende;

align 16;
 @step3:                     // spezial test
  cmp  eax,$EE808000;
  jb   @foult3;              // area for surrogates
  jae  @step31;              // priv zone

align 16;
 @foult30:
  cmp r10,2;
  je  @error2;
  call error_1;
  jmp @ende;
 @error2:
  movzx eax,word ptr [r9];
  bswap eax;

align 16;
 @foult3:
  bswap eax;
  mov  ecx,2;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jle  @ende;
  cmp  al,$E0;
  je   @E0;
  cmp  al,$ED;
  je   @ED;
align 16;
 @1:
  cmp  r10,0;
  jle  @ende;
  cmp  ecx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r9,1;
  sub  r10,1;
  sub  ecx,1;
  cmp  al,$BF;
  jbe  @1;
  call error_1;
  jmp  @1;
 @E0:
  cmp  ah,$A0;
  jae  @1;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
 @ED:
  cmp  ah,$9F;
  jbe  @1;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;                    // 4Byte -> result on surrogates!
 @Start4:
  cmp  r10,4
  jl   @foult40;
  mov  eax,dword ptr[r9];   // load 4 byte
  bswap eax;
  mov  ecx,eax;              // double the value
  and  ecx,$F8C0C0C0;        // test the bytes for conform
  cmp  ecx,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;
  cmp  eax,$F0908080;        // minimal value for 4 byte sequence
  jb   @foult4;
  cmp  eax,$F48FBFBF;        // maximal value for 4 Byte sequence
  ja   @foult4;
  bswap eax;                 // bswap for correct byte order
  and  eax,$3F3F3F07;        // and all the 4 byte
  xor  edx,edx;              // clear
  xor  ecx,ecx;              // clear ecx
  mov  dl,al;                // 1 Byte and 07 shl 18
  shl  edx,18;
  mov  cl,ah;                // 2 Byte and 3F shl 12
  shl  ecx,12;
  or   edx,ecx;              // inter result
  shr  eax,16;               // 3 and 4 byte -> ax
  sub  ecx,ecx;              // clear ecx
  mov  cl,al;                // 3 Byte and 3F shl 6
  shl  ecx,6;
  or   edx,ecx;              // inter result
  shr  eax,8;                // 4 Byte and 3F
  or   eax,edx;              // result UTF16 coding
  sub  eax,$10000;           // subtract 65536 from UTF16 word
  mov  edx,eax;              // save the result
  shr  eax,10;               // result div 1024
  add  eax,$D800;            // low surrogate = result + 55296
  test r8b,r8b;              // 0 = tyLE
  jz   @stepd1;
  xchg al,ah;                // byte order tyBE
 @stepd1:
  mov  word ptr[r11],ax;     // save the low surrogate UTF16 coding
  add  r11,2;                // destination pointer + 2
  and  edx,$3FF;             //
  add  edx,$DC00;            // high surrogate = result + 56320
  test r8b,r8b;              // 0 = tyLE
  jz   @stepd2;
  xchg dl,dh;                // byte order tyBE
 @stepd2:
  mov  word ptr[r11],dx;     // save the high surrogate UTF16 coding
  add  r11,2;                // destination pointer + 2
  add  r9,4;                // add source pointer + 4
  sub  r10,4;                // string length - 4
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp r10,3;
  je  @err3;
  cmp r10,2;
  je  @err2;
  call error_1;
  sub r10,1;
  jmp @ende;
 @err3:
  mov eax,dword ptr [r9];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [r9];
  bswap eax;

align 16;
 @foult4:
  bswap eax;
  mov  ecx,3;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  r10,0;
  jle  @ende;
  cmp  ecx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r9,1;
  sub  r10,1;
  sub  ecx,1;
  cmp  al,$BF;
  jbe  @a;
  call error_1;
  jmp  @a;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  r9,1;
  call error_1;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:               // mark invalid char
  add  r9,1;
  test r8b,r8b;              // check byte order
  jnz  @order;
  mov  word ptr[r11],$FFFD;  // error mark UTF16LE
  je   @go;                  // mov change no flags
 @order:
  mov  word ptr[r11],$FDFF;
 @go:
  add  r11,2;
  sub  r10,1
  jg   @Load;

align 16;
 @ende:
  xor  eax,eax;
  mov  word ptr[r11],ax;     // double Nul for UTF16 string
  mov  rax,r11;              // calculate the bytes
  pop  rdx;
  sub  rax,rdx;
  shr  rax,1;                // quantity of UTF16 chars
  pop  rcx;
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;

{The function convert on UTF8 coded string to on UTF32 coded string.
 The input string can have a BOM, this is not relevant and will ignored.
 The result string will saved without a BOM. Ill codepoints on input
 string is marked on result string. The result is the number of UTF32
 chars.
}
{$IFDEF FPC_HAS_CPSTRING}
function UTF8ToUTF32(const sText :Rawbytestring; pUTF32Char :Pointer):Int64;
     assembler;nostackframe;
{$else}
function UTF8ToUTF32(const sText :string; pUTF32Char :Pointer):Int64;
     assembler;nostackframe;
{$endif}

{ Input:
    rcx = addres sText
    rdx = addres lpUCS4Char

   Output:
    rax = count of UTF32 chars
    lpUCS4 coded string

   use registers:
    r9 = addres sText
    r11 = address lpUCS4char
    r10 = text length
    rax,rcx,rdx for convert
}

asm
  xor  rax,rax;
  {$ifndef WIN64}
  mov rcx,rdi:
  mov rdx,rsi:
  mov r8, rdx:
  mov r9, rcx:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  test rdx,rdx;
  jz   @stop;
  {$IFDEF FPC_HAS_CPSTRING}
  (* description: test it's a real UTF8 string *)
  movzx r9,word ptr[rcx-24];
  cmp  r9,65001;              // if UTF8string?
  jne  @stop;
  {$endif}
  mov  r10,qword ptr[rcx-8];  // string length
  cmp  r10,0;
  jle  @stop;
  jo   @stop;

  push rcx;
  push rdx;
  mov  r9 ,rcx;
  mov  r11,rdx;

  cmp  r10,3;                // if BOM possibility?
  jl   @Load;                // no, when < 3
  mov  eax,dword ptr[r9];   // load 4 byte from sText
  and  eax,$00FFFFFF;        // only 3 byte test
  cmp  eax,$00BFBBEF;        // UTF8 BOM?
  jne  @Load;
  add  r9,3;                // yes, correct the source Pointer
  sub  r10,3;
  jle  @ende;                // only BOM -> ende

align 16;
 @Load:
  mov  al,byte ptr[r9];     // load start byte for test
  cmp  al,$80;              // ASCII code?
  jb   @Start1;             // yes, 1 Byte
  cmp  al,$C2;              // $80...$C1 can not are start byte
  jb   @foultcoding;
  cmp  al,$DF;              // 2 byte sequenz
  jbe  @start2;
  cmp  al,$EF;              // 3 byte sequence
  jbe  @start3;
  cmp  al,$F4;              // 4 byte sequence
  jbe  @start4;
  ja   @foultcoding;        // no valid start byte -> error

align 16;
 @start1:                   // we found 1 Byte sequence
  and  eax,$000000FF;       // clear the upper bytes
  mov  dword ptr[r11],eax;  // save the UTF32 char
  add  r11,4;               // add destination pointer + 4
  add  r9,1;                // add source pointer + 1
  sub  r10,1;               // string length - 1
  jg   @Load;
  jle  @ende;

align 16;
 @start2:
  cmp  r10,2;               // string length >= 2 byte?
  jl   @foultcoding;
  movzx eax,word ptr[r9];   // load the 2 byte sequence
  bswap eax;
  mov  ecx,eax;             // save for lather
  and  ecx,$E0C00000;       // test of conform
  cmp  ecx,$C0800000;       // 110xxxxxx 10xxxxxx
  jne  @foult2;
  cmp  eax,$C2800000;       // min value range
  jb   @foult2;
  cmp  eax,$DFBF0000;       // max value range
  ja   @foult2;
  bswap eax;                // correct the byte order
  and  eax,$00003F1F;       // and the bytes
  xor  ecx,ecx;             // clear
  mov  cl,al;               // save al = al and 1F -> bl
  shl  cl,6;                // first Byte and 1F shl 6,
  shr  eax,8;               // second Byte 3F in al
  or   eax,ecx;             // result UTF32 char upper bytes is Nul for movzx
  mov  dword ptr[r11],eax;  // save the result
  add  r11,4;               // destination pointer + 2
  add  r9,2;                // add source pointer + 2
  sub  r10,2;               // string length - 2
  jg   @Load;
  jle  @ende;

align 16;
 @foult2:
  bswap eax;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jle  @ende;
  cmp  ah,$80;               // is a start byte?
  jb   @Load;
  cmp  ah,$C2;               // dito
  jae  @Load;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @start3:                    // found a 3 byte sequence
  cmp  r10,3                 // string length >= 3 byte
  jl   @foult30;
  mov  eax,dword ptr[r9];   // load 4 Byte
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
  xor  edx,edx;              // clear
  xor  ecx,ecx;              // clear ecx
  mov  dl,al;                // 1 Byte -> bl
  shl  edx,12;               // byte 1 = bl and 0F shl 12
  mov  cl,ah;                // 2 Byte -> cl
  shl  ecx,6;                // byte 2 = cl and 3F shl 6;
  or   edx,ecx;              // inter result bl or cl
  shr  eax,16;               // 3 byte = and EF
  or   eax,edx;              // result UTF32 coding
  mov  dword ptr[r11],eax;   // save the UTF32 coding
  add  r11,4;                // destination + 4
  add  r9,3;                 // source pointer + 3
  sub  r10,3;                // string length - 3
  jg   @Load;
  jle  @ende;

align 16;
 @step3:
   cmp eax,$EE808000;
   jb  @foult3;             // when < surrogate range
   jae @step31;

align 16;
 @foult30:
  cmp r10,2;
  je  @error2;
  mov dword ptr [r11],$0000FFFD;
  add r11,4;
  jmp @ende;
 @error2:
  movzx eax,word ptr [r9];
  bswap eax;

align 16;
 @foult3:
  bswap eax;                      // correct byte order for tests
  mov  ecx,2;                     // max count for follow test
  add  r9,1;                      // add source pointer
  mov  dword ptr [r11],$0000FFFD; // error mark in destination
  add  r11,4;                     // add destination pointer
  sub  r10,1;
  jle  @ende;
  cmp  al,$E0;                    // test first byte
  je   @E0;
  cmp  al,$ED;
  je   @ED;
align 16;
 @1:
  cmp  r10,0;
  jle  @ende;
  cmp  ecx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;                   // is start byte?
  jb   @Load;
  cmp  al,$C2;                   // dito
  jae  @Load;
  add  r9,1;
  sub  r10,1;
  sub  ecx,1;
  cmp  al,$BF;
  jbe  @1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  jmp  @1;
align 16;
 @E0:
  cmp  ah,$A0;
  jae  @1;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
align 16;
 @ED:
  cmp  ah,$9F;
  jbe  @1;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @Start4:                    // found 4 byte sequence
  cmp  r10,4                 // string lengt >= 4 Byte
  jl   @foult40;
  mov  eax,dword ptr[r9];    // load 4 byte
  bswap eax;
  mov  ecx,eax;              // double the value
  and  ecx,$F8C0C0C0;        // test the bytes for conform
  cmp  ecx,$F0808080;        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  jne  @foult4;
  cmp  eax,$F0908080;        // minimal value for 4 byte sequence
  jb   @foult4;
  cmp  eax,$F48FBFBF;        // maximal value for 4 Byte sequence
  ja   @foult4;
  bswap eax;                 // correct the byte order
  and  eax,$3F3F3F07;
  xor  edx,edx;              // clear
  xor  ecx,ecx;              // clear ecx
  mov  dl,al;                // first Byte al and 07 shl 18
  shl  edx,18;
  mov  cl,ah;                // second Byte ah and 3F shl 12
  shl  ecx,12;
  or   edx,ecx;              // first or second byte
  shr  eax,16;               // byte 3 and 4 -> ax
  xor  ecx,ecx;              // clear ecx
  mov  cl,al;                // 3 Byte
  shl  ecx,6;                // byte 3 and 3F shl 6
  or   edx,ecx;              // or all the inter results
  shr  eax,8;                // 4 Byte and 3F
  or   eax,edx;              // or all -> UTF32 coding
  mov  dword ptr[r11],eax;   // save the UTF32 coding
  add  r11,4;                // add destination + 4
  add  r9,4;                // source pointer + 4
  sub  r10,4;                // string length - 4
  jg   @Load;
  jle  @ende;

align 16;
 @foult40:
  cmp r10,3;
  je  @err3;
  cmp r10,2;
  je  @err2;
  mov dword ptr [r11],$0000FFFD;
  add r11,4;
  jmp @ende;
 @err3:
  mov eax,dword ptr [r9];
  and eax,$00FFFFFF;
  bswap eax;
  jmp @foult4;
 @err2:
  movzx eax,word ptr [r9];
  bswap eax;

align 16;
 @foult4:
  bswap eax;
  mov  ecx,3;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jle  @ende;
  cmp  al,$F0;
  je   @F0;
  cmp  al,$F4;
  je   @F4;
align 16;
 @a:
  cmp  r10,0;
  jle  @ende;
  cmp  ecx,0;
  jle  @Load;
  shr  eax,8;
  cmp  al,$80;
  jb   @Load;
  cmp  al,$C2;
  jae  @Load;
  add  r9,1;
  sub  r10,1;
  sub  ecx,1;
  cmp  al,$BF;
  jbe  @a;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  jmp  @a;
align 16;
 @F0:
  cmp  ah,$90;
  jae  @a;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jg   @Load;
  jle  @ende;
align 16;
 @F4:
  cmp  ah,$8F;
  jbe  @a;
  add  r9,1;
  mov  dword ptr [r11],$0000FFFD;
  add  r11,4;
  sub  r10,1;
  jg   @Load;
  jle  @ende;

align 16;
 @foultcoding:               // foult coding -> UNICODE-Standard!
  add  r9,1;
  mov  dword ptr[r11],$0000FFFD; // error mark UTF32LE
  add  r11,4;
  sub  r10,1;
  jg   @load;

align 16;
 @ende:
  xor  eax,eax;
  mov  dword ptr[r11],eax;   // Nul dword
  add  r11,4;
  mov  rax,r11;              // array length in byte
  pop  rdx;
  sub  rax,rdx;
  shr  rax,2;                // array length on UTF32 chars
  pop  rcx;
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;


{-----------------------UTF16--------------------------------------------}

{The function convert a UTF16 coded string on a UTF8 coded string.
 The byte order from input string is on parameter InByteOrder. Has the
 input string a BOM then the function compare the input from parameter
 InByteOrder with the BOM. On case of a diffrent the function stop the
 converting and give a Nulstring as result. Ill codepoints on input
 string will marked on result string. The result string is saved without
 BOM. The function result is the number of UTF8 bytes.
}
function UTF16ToUTF8(const sUTF16 :Unicodestring; pUTF8 :Pointer;
  InByteOrder :TByteOrder):Int64;assembler;nostackframe;

{ Input:
   rcx = addres pUTF16
   rdx = addres pUTF8 pointer
   r8  = ByteOrder; 0 = tyLE, 1 = tyBE

  Output:
   rax = number of UTF8 bytes
   pUTF8 UTF8string

  register use:
    r8  = ByteOrder
    r10 = string length
    rcx = address sText
    rdx = addres pUTF8
    rax,r9,r11 for convert
}
 asm
   xor  rax,rax;
  {$ifndef WIN64}
   mov rcx,rdi:
   mov rdx,rsi:
   mov r8, rdx:
   mov r9, rcx:
  {$endif}
   test rcx,rcx;
   jz   @stop;
   test rdx,rdx;
   jz   @stop;
   mov  r10,qword ptr[rcx-8]; // number of UTF16chars d.h. 2 bytes pro char!
  {$IFDEF VER2_6_4}
   shr  r10,1                 // we need the count of char for consistence
                              // FPC264 give the Length in bytes Bytes
  {$ENDIF}
   cmp  r10,0;
   jle  @stop;
   jo   @stop;

   push rcx;                 // save the start adress
   push rdx;

   //BOM
   movzx eax,word ptr[rcx];
   cmp  eax,$0000FEFF;        // UTF16LE   RFC2781
   je   @LE;
   cmp  eax,$0000FFFE;        // UTF16BE   RFC2781
   je   @BE;
   jmp  @a1;

  @BE:
   test r8b,r8b;              // 0 = tyLE
   jz   @error                // different BOM = BE but ByteOrder = LE
   jmp  @step00;
  @LE:
   test r8b,r8b;              // 0 = tyLE
   jnz  @error                // different BOM = LE but ByteOrder = BE
  @step00:
   add  rcx,2;                // string start with BOM
   sub  r10,1;
   jle  @error;               // only BOM is error!
  @a1:
   test r8b,r8b;
   jnz  @loadBE;

(* for UTF16LE (intel) *)
align 16;
  @loadLE:
   movzx eax,word ptr[rcx];   // load UTF16 char
   cmp  eax,$80;              // check the bytes for convert on UTF8
   jb   @Start1;              // 1 Byte convert, is ASCII
   cmp  eax,$800;
   jb   @Start2;              // 2 byte convert
   cmp  eax,$D800;
   jb   @start3;
   cmp  eax,$DFFF;
   jbe  @surroLE;             // 4 Byte convert
   ja   @start3;              // E000...FFFF is priv. zone -> 3 byte

(* for UTF16BE *)
align 16;
 @loadBE:
  movzx eax,word ptr[rcx];   // load UTF16 chars
  xchg al,ah;
  cmp  eax,$80;              // check the bytes for convert on UTF8
  jb   @Start1;              // 1 Byte convert, is ASCII
  cmp  eax,$800;
  jb   @Start2;              // 2 byte convert
  cmp  eax,$D800;
  jb   @start3;
  cmp  eax,$DFFF;
  jbe  @surroBE;             // 4 Byte convert
  ja   @start3;              // E000...FFFF is priv. zone -> 3 byte

align 16;
  @Start3:                    // convert on 3 byte
   mov  r9d,eax;              // save for later
   shr  r9d,12;               // 1 byte
   or   r9d,$000000E0;
   mov  byte ptr[rdx],r9b;
   add  rdx,1;
   mov  r9d,eax;              // 2 byte
   shr  r9d,6;
   and  r9d,$0000003F;
   or   r9d,$00000080;
   mov  byte ptr[rdx],r9b;
   add  rdx,1;
   and  eax,$0000003F;        // 3 byte
   or   eax,$00000080;
   mov  byte ptr[rdx],al;
   add  rdx,1;
   add  rcx,2;
   sub  r10,1;
   jle  @ende;
   test r8b,r8b;
   jz   @loadLE;
   jnz  @loadBE;

align 16;
  @Start2:                   // convert on 2 byte
   mov  r9d,eax;             // save for later
   shr  eax,6;               // 1 byte
   or   eax,$000000C0;
   mov  byte ptr[rdx],al;
   add  rdx,1;
   and  r9d,$0000003F;       // 2 byte
   or   r9d,$00000080;
   mov  byte ptr[rdx],r9b;
   add  rdx,1;
   add  rcx,2;
   sub  r10,1;
   jle  @ende;
   test r8b,r8b;
   jz   @loadLE;
   jnz  @loadBE;

align 16;
  @Start1:
   mov  byte ptr[rdx],al;
   add  rdx,1;
   add  rcx,2;
   sub  r10,1;
   jle  @ende;
   test r8b,r8b;
   jz   @loadLE;
   jnz  @loadBE;

align 16;
  @surroBE:                    // we found a surrogate word
   cmp  r10,2;
   jle  @foult0;               // we need 2 words
   mov  eax,dword ptr[rcx];    // the string have a Nul at end
   bswap eax;                  // so we not have a error
   rol  eax,16;
   jmp  @sur;

align 16;
  @surroLE:
   cmp  r10,2;
   jle  @foult0;
   mov  eax,dword ptr[rcx];
  @sur:
   mov  r11d,eax;
   and  r11d,$0000FFFF;
   cmp  r11d,$0000D800;       // test range for high surrogate
   jb   @foultcoding;        // when low surro first -> error
   cmp  r11d,$0000DBFF;
   ja   @foultcoding;
   mov  r11d,eax;
   shr  r11d,16;
   cmp  r11d,$0000DC00;       // test range for low surrogate
//   jb   @foultcoding2;
   jb   @foultcoding;
   cmp  r11d,$0000DFFF;       // E000...FFFF is private zone
   ja   @priv;

   mov  r9d,eax;              // saved value to ecx
   mov  r11d,eax;
   and  r9d,$0000FFFF;         // high surro
   sub  r9d,$0000D800;
   shl  r9d,10;
   shr  r11d,16;                // low surro
   sub  r11d,$0000DC00;
   add  r11d,$10000;
   add  r9d,r11d               // we have a UTF32 value
   mov  r11d,r9d;              // save the UTF32 value
   shr  r9d,18;               // 1 byte
   or   r9d,$000000F0;
   mov  byte ptr[rdx],r9b;
   add  rdx,1;
   mov  r9d,r11d;              // 2 byte
   shr  r9d,12;
   and  r9d,$0000003F;
   or   r9d,$00000080;
   mov  byte ptr[rdx],r9b;
   add  rdx,1;
   mov  r9d,r11d;              // byte 3
   shr  r9d,6;
   and  r9d,$0000003F;
   or   r9d,$00000080;
   mov  byte ptr[rdx],r9b;
   add  rdx,1;
   and  r11d,$0000003F;       // byte 4
   or   r11d,$00000080;
   mov  byte ptr[rdx],r11b;
   add  rdx,1;
   add  rcx,4;
   sub  r10,2;
   jle  @ende;
   cmp  r8,0;
   je   @loadLE;
   jne  @loadBE;

align 16;
  @priv:
   mov dword ptr[rdx],$00BDBFEF; // mark error we have surro before
   add rdx,3;
   add rcx,2;
   sub r10,1;
   mov eax,r11d;                  // priv. value
   jmp @start3;                  // priv. zone convert to 3 byte

//align 16;
//  @foultcoding2:
//   mov dword ptr[rdi],$00BDBFEF; // part 2 from surro is ill coding
//   add rdi,3;                    // mark both
//   add rsi,2;
//   sub r10,1;
align 16;
 @foultcoding:                     // for surrogates
   mov dword ptr[rdx],$00BDBFEF;
   add rdx,3;
   add rcx,2;
   sub r10,1;
   jle @ende;
   test r8b,r8b;
   jz  @loadLE;
   jnz @loadBE;

align 16;
  @error:
   pop  rdx;
   pop  rcx;
   xor  rax,rax;              // Nul
   jmp  @stop;

align 16;
 @foult0:
   mov dword ptr[rdx],$00BDBFEF;
   add rdx,3;
   // all words processed

align 16;
  @ende:
   xor  eax,eax;
   mov  byte ptr[rdx],al;     // Nul Byte
   mov  rax,rdx;              // string length on bytes
   pop  rdx;
   sub  rax,rdx;
   pop  rcx;
  @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
 end;

{ The function convert a UTF16 encoded string on a UTF32 encoded string.
  The byte order from the input string is on parameter InByteOrder.
  Has the input string a BOM then the function compare this with the
  input of InByteOrder. On case of a diffrent the function stop and give
  a Nul string as result. The result string is without BOM. Ill codepoints
  on input string will marked on result string. The function result is the
  number of UTF32 chars.
}
function UTF16ToUTF32(const sUTF16 :Unicodestring; pUCS4 :Pointer;
  InByteOrder :TByteOrder):Int64;assembler;nostackframe;

{ Input:
    rcx = addres pUTF16
    rdx = addres pUCS4
    r8  = byte order

   Output:
    rax = count of UCS4Chars
    pUCS4Char = addres coded UTF32 string

   use register
     r8  = byte order; 1 = UTF16BE 0 = UTF16LE
     rcx = addres sText
     rdx = addres UTF32 string
     r10 = length of sText
     rax,r9 for convert
}

 asm
   xor  rax,rax;
   {$ifndef WIN64}
   mov rcx,rdi:
   mov rdx,rsi:
   mov r8, rdx:
   mov r9, rcx:
  {$endif}
   test rcx,rcx;
   jz   @stop;
   test rdx,rdx;
   jz   @stop;
   test r8b,r8b;
   setnz r8b;
   mov  r10,qword ptr[rcx-8]; // string length
  {$IFDEF VER2_6_4}
   shr  r10,1                 // we need count of bytes consist with older
                              // version of free pascal
  {$ENDIF}
   cmp  r10,0
   jle  @stop;
   jo   @stop;

   push rcx;                 // save start adress
   push rdx;

   //BOM
   movzx eax,word ptr[rcx];
   cmp  eax,$0000FEFF;        // UTF16LE   RFC2781
   je   @LE;
   cmp  eax,$0000FFFE;        // UTF16BE   RFC2781
   je   @BE;
   jmp  @a1;

  @BE:
   test r8b,r8b;              // 0 = tyLE
   jz   @error;               // different BOM = BE but byteorder = tyLE
   jmp  @step00;
  @LE:
   test r8b,r8b;              // 0 = tyLE
   jnz  @error;               // different BOM = LE but byteorder = tyBE
  @step00:
   add  rcx,2;                // add source pointer + 2
   sub  r10,1                 // string length - 2
   jle  @error                // only BOM
  @a1:
   test r8b,r8b;              // 0 tyLE
   jnz  @loadBE;

(* for UTF16LE (intel) *)
align 16;
 @loadLE:
  movzx eax,word ptr[rcx];   // load UTF16 char
  cmp  eax,$0000D800;
  jae  @surroLE;             // found surrogate byte
  mov  dword ptr[rdx],eax;   // save the UTF32 coding
  add  rdx,4;                // add destination + 4
  add  rcx,2;                // correct source pointer
  sub  r10,1;
  jg   @loadLE;
  jle  @ende;

align 16;
 @surroLE:
  cmp  eax,$0000DFFF;
  ja   @priv0;               // private zone
  cmp  r10,2;
  jle  @foult0;
  mov  eax,dword ptr[rcx];   // we need all 2 words
  mov  r9d,eax;              // for tests
  and  r9d,$0000FFFF;
  cmp  r9d,$0000D800;        // test range for high surrogate
  jb   @foultcoding;         // high surrogate must be first!
  cmp  r9d,$0000DBFF;
  ja   @foultcoding;
  mov  r9d,eax;
  shr  r9d,16;
  cmp  r9d,$0000DC00;        // test low surrogate range
//  jb   @foultcoding2;
  jb   @foultcoding;
  cmp  r9d,$0000DFFF;        // E000...FFFF is priv. zone!
  ja   @priv1;

  mov  r9d,eax;
  and  r9d,$0000FFFF;        // high surro
  sub  r9d,$0000D800;
  shl  r9d,10;
  shr  eax,16;
  sub  eax,$0000DC00;        // low surro
  add  eax,$10000;
  add  r9d,eax               // we have a UTF32 value
  mov  dword ptr[rdx],r9d;
  add  rdx,4;
  add  rcx,4;
  sub  r10,2;
  jg   @loadLE;
  jle  @ende;


(* for UTF16BE *)
align 16;
 @loadBE:
  movzx eax,word ptr[rcx];
  xchg al,ah;
  cmp  eax,$0000D800;
  jae  @surroBE;
  mov  dword ptr[rdx],eax;
  add  rdx,4;
  add  rcx,2;
  sub  r10,1;
  jg   @loadBE;
  jle  @ende;

align 16;
 @surroBE:
  cmp  eax,$0000DFFF;
  ja   @priv0;               // private zone
  cmp  r10,2;
  jle  @foult0;
  mov  eax,dword ptr[rcx];   // we need all 2 words
  bswap eax;
  rol  eax,16;
  mov  r9d,eax;              // for tests
  and  r9d,$0000FFFF;
  cmp  r9d,$0000D800;        // test range for high surrogate
  jb   @foultcoding;         // high surrogate must be first!
  cmp  r9d,$0000DBFF;
  ja   @foultcoding;
  mov  r9d,eax;
  shr  r9d,16;
  cmp  r9d,$0000DC00;        // test low surrogate range
//  jb   @foultcoding2;
  jb   @foultcoding;
  cmp  r9d,$0000DFFF;        // E000...FFFF is priv. zone!
  ja   @priv1;

  mov  r9d,eax;
  and  r9d,$0000FFFF;        // high surro
  sub  r9d,$0000D800;
  shl  r9d,10;
  shr  eax,16;
  sub  eax,$0000DC00;        // low surro
  add  eax,$10000;
  add  r9d,eax               // we have a UTF32 value
  mov  dword ptr[rdx],r9d;
  add  rdx,4;
  add  rcx,4;
  sub  r10,2;
  jg   @LoadBE;
  jle  @ende;


(* for UTF16LE and UTF16BE *)
align 16;
 @priv1:                      // range private zone
  mov  dword ptr[rdx],$FFFD;  // error mark, we found surro before
  add  rdx,4;
  add  rcx,2;                 // we have load 2 words here 1 word
  sub  r10,1;
  mov  eax,ecx;               // priv value
align 16;
 @priv0:
  mov  dword ptr[rdx],eax;
  add  rdx,4;
  add  rcx,2;                 // here 1 word
  sub  r10,1;
  jle  @ende;
  test r8b,r8b;
  jz   @loadLE;
  jnz  @loadBE;

//align 16;
// @foultcoding2:              // part 2 of surro is ill coding
//  mov  dword ptr[rdx],$FFFD; // mark both
//  add  rdx,4;
//  add  rcx,2;
//  sub  r10,1;
align 16;
 @foultcoding:
  mov  dword ptr[rdx],$FFFD; // part 1 of surro is ill coding
  add  rdx,4;
  add  rcx,2;
  sub  r10,1;
  jle  @ende;
  test r8b,r8b;
  jz   @loadLE;
  jnz  @loadBE;

align 16;
 @error:
  pop rdx;
  pop rcx;
  xor rax,rax;              // Nul Byte
  jmp @stop;

align 16;
 @foult0:
  mov  dword ptr[rdx],$FFFD;
  add  rdx,4;
  // all words processed

align 16;
 @ende:
  xor  eax,eax;
  mov  dword ptr[rdx],eax;   // Nul dword
  add  rdx,4;
  mov  rax,rdx;              // Size on byte
  pop  rdx;
  sub  rax,rdx;              // chars on string
  shr  rax,2;
  pop  rcx;
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;


(*-------------------------UTF32-------------------------------------------*)

{ The function count the bytes for the convert from a UTF32 encoded string
  to a UTF8 encoded string. The function also count ill codepoints. The
  result is the number of UTF8 bytes.
}
function UTF32ToUTF8Length(constref sText :UCS4String):Int64;
          assembler;nostackframe;

{ Input:
    rcx = sText,

   Output:
    rax = count of Byte

   register use:
    r8  = addres of sText
    r9  = counter
    r10 = UTF32 length
    rax,rcx intern

}

  asm
  xor  rax,rax;
 {$ifndef WIN64}
  mov rcx,rdi:
  mov rdx,rsi:
  mov r8, rdx:
  mov r9, rcx:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  mov  r8, qword ptr[rcx];  // addres of sText
  mov  r10,qword ptr[r8-8]; // count of UTF32 chars
  cmp  r10,0;
  jle  @stop;
  jo   @stop;

  xor  r9,r9;                // clear counter
  mov  eax,dword ptr[r8];    // load first dword and test for BOM
  cmp  eax,$FFFE0000;        // UTF32BE
  je   @stop;
  cmp  eax,$0000FEFF;        // UTF32LE
  jne  @Load;
  add  r9,3;                // count BOM we no use BOM but for exact count
  add  r8,4;                 // array start with BOM
  sub  r10,1
  jle  @error;               // only BOM -> error

align 16;
 @load:
  mov  eax,dword ptr[r8];    // load  UTF32 char
  add  r8,4;                 // add addres pointer + 8
  cmp  eax,$FDFF0000;        // error mark
  je   error;
  cmp  eax,$80;
  jb   @Start1;              // convert to 1 byte
  cmp  eax,$800;
  jb   @Start2;              // convert to 2 byte
  cmp  eax,$E000;
  jb   @error;
  cmp  eax,$10000;
  jb   @Start3;              // convert to 3 byte
  cmp  eax,$10FFFF;
//  jbe  @Start4;
  ja   @error;

  //Start4:
  add  r9,4;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start1:
  add  r9,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start2:
  add  r9,2;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start3:
  add  r9,3;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @error:
  add r9,3;
  sub r10,1;
  jg  @Load;

align 16;
 @ende:
  mov  rax,r9;              // UTF8 length on Byte
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;

{ The function count the UTF16 chars on the UTF32 string. The function
   also count ill codepoints. The function result is the number of UTF16
   chars.
}
function UTF32ToUTF16Length(constref sText :UCS4String):Int64;
          assembler;nostackframe;

{ Input:
    rcx = adress sText,

   Output:
    rax = count of Byte

   register use:
    r9 = counter of UTF16 char
    r8  = adress sText;
    r10 = string length
}

  asm
  xor  rax,rax;
 {$ifndef WIN64}
  mov rcx,rdi:
  mov rdx,rsi:
  mov r8, rdx:
  mov r9, rcx:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  mov  r8, qword ptr[rcx];   // addres of sText
  mov  r10,qword ptr[r8-8];  // count of UTF32 chars
  cmp  r10,0;
  jle  @stop;
  jo   @stop;

  push rcx;
  xor  r9,r9;                // clear char counter
  mov  eax,dword ptr[r8];    // load first dword and test for BOM
  cmp  eax,$FFFE0000;        // UTF32BE
  je   @stop;
  cmp  eax,$0000FEFF;        // UTF32LE
  jne  @load;
  add  r8,4;                 // array start with BOM
  add  r9,1;                 // we count BOM
  sub  r10,1
  jle  @error;               // only BOM -> error

align 16;
 @load:
  mov  eax,dword ptr[r8];   // load  UTF32char
  add  r8,4;                // add addres pointer
  cmp  eax,$0000FFFF;
  ja   @surro;
  add  r9,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @surro:
  cmp  eax,$0010FFFF;     // > ill codepoint
  ja   @foult;
  add  r9,2;
  sub  r10,1;
  jg   @load;
  jle  @ende;
align 16;
 @foult:
  add  r9,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @error:
  pop rcx;
  xor rax,rax;
  jmp @stop;

align 16;
 @ende:
  mov  rax,r9;              // UTF16 chars
  pop  rcx;
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;

{ The function convert a UTF32 encoded string on a UTF16 encoded string.
  The byte order (BOM) for the result string is on parameter OutByteOrder.
  Has the input string a BOM this is not relevant and will ignored. The
  result string is saved without BOM. Ill codepoints on input string is
  marked on the result string. The result addres is on parameter pUni.
  The function result is the number of UTF16 chars.
}
function UTF32ToUTF16(constref sUTF32 :UCS4string; pUni :Pointer;
   OutByteOrder :TByteOrder):Int64;assembler;nostackframe;

{ Input:
    rcx = addres of sUTF32
    rdx = addres pUni
    r8  = OutByteOrder 0 = tyLE, 1 = tyBE

   Output:
    rax = number of UTF16 chars
    rdx = pUni converted string (rsi for not Win64)

   register use:
    rdx = addres pUni
    r8b = byte order
    r9  = addres sUCS4
    r10 = string length
    rax,rcx for convert

Remark: Load of 2 UTF32 chars per round give no more speed.(I have this tested)
}

asm
  xor  rax,rax;
 {$ifndef WIN64}
  mov rcx,rdi:
  mov rdx,rsi:
  mov r8, rdx:
  mov r9, rcx:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  test rdx,rdx;
  jz   @stop;
  mov  r9, qword ptr[rcx];
  mov  r10,qword ptr[r9-8];  // array quantity, d.h. quantity of chars!
  cmp  r10,0;                // is string 0?
  jle  @stop;
  jo   @stop;

// BOM
  mov  eax,dword ptr[r9];
  cmp  eax,$FFFE0000;        // UTF32BE
  je   @stop;
  push rcx;
  push rdx;                  // save the start addres
  cmp  eax,$0000FEFF;        // UTF32LE
  jne  @order;
  sub  r10,1;
  jle  @error;               // only BOM -> error
  add  r9,4;                 // string start with BOM
 @order:
  test r8b,r8b;             // 0 tyLE
  jnz  @LoadBE;

(* for UTF16LE *)
align 16;
 @loadLE:
  mov  eax,dword ptr[r9];    // load UTF32 Char
  add  r9,4;                 // correct source pointer
  cmp  eax,$0000D800;        // D800 - DFFF is ill on UTF32!
  jae  @next;
 @normLE:
  mov  word ptr[rdx],ax;
  add  rdx,2;
  sub  r10,1;                // subtract length
  jg   @loadLE;
  jle  @ende;
align 16;
 @next:
  cmp  eax,$0000DFFF;       // range E000...FFFF is seldem use
  jbe  @foultcodingLE;
  cmp  eax,$0000FFFF;
  jbe  @normLE;

align 16;
 @surroLE:
  cmp  eax,$0010FFFF;
  ja   @foultcodingLE;      // over defined range
  sub  eax,$10000;
  mov  ecx,eax;
  shr  ecx,10;
  add  ecx,$D800;
  mov  word ptr[rdx],cx;
  add  rdx,2;
  and  eax,$000003FF;
  add  eax,$0000DC00;
  mov  word ptr[rdx],ax;
  add  rdx,2;
  sub  r10,1;
  jg   @loadLE;
  jle  @ende;

align 16;
 @foultcodingLE:
  mov  word ptr[rdx],$FFFD;     // mark foult coding
  add  rdx,2;
  sub  r10,1;
  jg   @loadLE;
  jle  @ende;

(* for UTF16BE *)
align 16;
 @loadBE:
  mov  eax,dword ptr[r9];    // load UTF32 Char
  add  r9,4;                 // correct source pointer
  cmp  eax,$0000D800;        // D800 - DFFF is ill on UTF32!
  jae  @next1;
 @normBE:
  xchg al,ah;
  mov  word ptr[rdx],ax;
  add  rdx,2;
  sub  r10,1;
  jg   @LoadBE;
  jle  @ende;
align 16;
 @next1:
  cmp  eax,$0000DFFF;
  jbe  @foultcodingBE;
  cmp  eax,$0000FFFF;
  jbe  @normBE;

align 16;
 @surroBE:
  cmp  eax,$0010FFFF;
  ja   @foultcodingBE;
  sub  eax,$10000;
  mov  ecx,eax;
  shr  ecx,10;
  add  ecx,$D800;
  xchg cl,ch;
  mov  word ptr[rdx],cx;
  add  rdx,2;
  and  eax,$000003FF;
  add  eax,$0000DC00;
  xchg al,ah;
  mov  word ptr[rdx],ax;
  add  rdx,2;
  sub  r10,1;
  jg   @loadBE;
  jle  @ende;

align 16;
 @foultcodingBE:
  mov  word ptr[rdx],$FDFF;     // mark foult coding
  add  rdx,2;
  sub  r10,1;
  jg   @loadBE;
  jle  @ende;

align 16;
 @error:
  pop  rdx;
  pop  rcx;
  xor  rax,rax;              // Nul
  jmp  @stop;

align 16;
 @ende:
  mov  word ptr[rdx],$0000;  // Nul char
  mov  rax,rdx;              // compute the bytes
  pop  rdx;
  pop  rcx;
  sub  rax,rdx;
  shr  rax,1;                // count of UTF16 chars
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;


{ The function convert a UTF32 encoded string on a UTF8 encoded string.
  Has the UTF32 string a BOM is not relevant and will ignored. Ill
  codepoints on the UTF32 coded string is marked on result string. The
  result string is saved without BOM. The function result is the number
  of bytes.
}
function UTF32ToUTF8(constref sUTF32 :UCS4string; pUTF8 :Pointer):Int64;
    assembler;nostackframe;

{ Input:
    rcx = pointer of sUCS4 addres
    rdx = addres pUTF8 Pointer

   Output:
    rax = count of Bytes
    rdx = pUTF8 converted string (rsi for not Win64)

   register use:
    r8  = adress pUTF8
    r9  = addres sUCS4
    r10 = string length
    rax,r11 for convert
}

asm
  xor  rax,rax;
 {$ifndef WIN64}
  mov rcx,rdi:
  mov rdx,rsi:
  mov r8, rdx:
  mov r9, rcx:
 {$endif}
  test rcx,rcx;
  jz   @stop;
  test rdx,rdx;
  jz   @stop;
  mov  r9, qword ptr[rcx];   // addres for sUTF32 for constref -> [rcx]
  mov  r10,qword ptr[r9-8];  // array quantity
  cmp  r10,0;                // is array 0?
  jle  @stop;
  jo   @stop;

  mov  r8,rdx;               // address pUTF8

  //BOM
  mov  eax,dword ptr[r9];
  cmp  eax,$FFFE0000;        // UTF32BE
  je   @stop;
  cmp  eax,$0000FEFF;        // UTF32LE
  jne  @Load;
  sub  r10,1;
  jle  @error;               // only BOM -> error
  add  r9,4;                 // string start with BOM

align 16;
 @load:
  mov  eax,dword ptr[r9];    // load UTF32 Char
  add  r9,4;                 // correct source pointer
  cmp  eax,$00000080;
  jb   @Start1;              // convert to 1 byte
  cmp  eax,$00000800;
  jb   @Start2;              // convert to 2 byte
  cmp  eax,$0000D800;
  jb   @Start3;              // convert to 3 byte
  cmp  eax,$0000DFFF;        // ill codepoints D800 - DFFF on UTF32 (surrogate)
  jbe  @foultcoding;
  cmp  eax,$00010000;
  jb   @Start3;              // convert to 3 byte
  cmp  eax,$0010FFFF;
  ja   @foultcoding;

  // @Start4:
  mov  r11d,eax;
  shr  r11d,18;                        // byte 1
  or   r11d,$000000F0;
  mov  byte ptr[r8],r11b;
  add  r8,1;
  mov  r11d,eax;                       // byte 2
  shr  r11d,12;
  and  r11d,$0000003F;
  or   r11d,$00000080;
  mov  byte ptr[r8],r11b;
  add  r8,1;
  mov  r11d,eax;                       // byte 3
  shr  r11d,6;
  and  r11d,$0000003F;
  or   r11d,$00000080;
  mov  byte ptr[r8],r11b;
  add  r8,1;
  and  eax,$0000003F;                 // byte 4
  or   eax,$00000080;
  mov  byte ptr[r8],al;
  add  r8,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start1:
  mov  byte ptr[r8],al;
  add  r8,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start2:
  mov  r11d,eax;
  shr  r11d,6;                 // byte 1
  or   r11d,$000000C0;
  mov  byte ptr[r8],r11b;
  add  r8,1;
  and  eax,$0000003F;         // byte 2
  or   eax,$00000080;
  mov  byte ptr[r8],al;
  add  r8,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @Start3:
  mov  r11d,eax;
  shr  r11d,12;                // byte 1
  or   r11d,$0000E0;
  mov  byte ptr[r8],r11b;
  add  r8,1;
  mov  r11d,eax;               // byte 2
  shr  r11d,6;
  and  r11d,$0000003F;
  or   r11d,$00000080;
  mov  byte ptr[r8],r11b;
  add  r8,1;
  and  eax,$0000003F;         // byte 3
  or   eax,$00000080;
  mov  byte ptr[r8],al;
  add  r8,1;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @foultcoding:
  mov  dword ptr[r8],$00BDBFEF; // mark foult coding
  add  r8,3;
  sub  r10,1;
  jg   @load;
  jle  @ende;

align 16;
 @error:
  xor  rax,rax;              // Size in Byte
  jmp  @stop;

align 16;
 @ende:
  mov  byte ptr[r8],$00     // Nul byte
  mov  rax,r8;
  sub  rax,rdx;             // count of bytes
 @stop:
 {$ifndef WIN64}
  xor rdx,rdx;
 {$endif}
end;


(*--------------------Pascal------------------------------------------*)

{The system setcodepage routine has many overhead}
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
function fnUTF8ToUTF16(const sText :Rawbytestring;
                     OutByteOrder :TByteOrder = tyLE):Unicodestring;
{$else}
function fnUTF8ToUTF16(const sText :string;
                     OutByteOrder :TByteOrder = tyLE):Unicodestring;
{$endif}
 var
   iChar :Int64;

{ The system routine think each UTF8 byte is converting to one
  UTF16 char (valid when only ASCII chars). That is rapid, but
  reserve memory witch real not needed.
  Therefore we count the result chars for the UTF16 string and so
  we need less memory. Yes cost run time for scan.
  Remark:
  - when OutbyteOrder is tyBE, then you can not use Freepascal for working
    with this result string. This is only for file transfer for working
     systems with diffrent byte order in memory p.e MIPS,IBM }
begin
  Result := '';
  if sText <> '' then begin
    // quantity of UTF16 chars
    iChar := UTF8ToUTF16Length(sText);
    if iChar > 0 then begin
      SetLength(Result,iChar);
      iChar := UTF8ToUTF16(sText,Pointer(Result),OutByteOrder);
      if iChar > 0 then begin
        SetLength(Result,iChar);
        {$IFDEF FPC_HAS_CPSTRING}
          if OutByteorder = tyBE then
            // not code conversion use separate coding
            fnSetCodePage(@Result,12001);
        {$ENDIF}
       end
      else
        Result := '';
    end;
  end;
end;

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF8ToUTF32(const sText :Rawbytestring):UCS4String;
{$else}
function fnUTF8ToUTF32(const sText :string):UCS4String;
{$endif}
 var
   iChar :Int64;
begin
  Result := nil;
  if sText <> '' then begin
    // count of chars
    iChar := fnUTF8Length(sText);
    if iChar > 0 then begin
      SetLength(Result,iChar);
      iChar := UTF8ToUTF32(sText,Pointer(Result));
      if iChar > 0 then
        SetLength(Result,iChar)
      else
        Result := nil;
    end;
  end;
end;

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF16ToUTF8(const sText :Unicodestring;
     InByteOrder :TByteOrder = tyLE):Rawbytestring;
{$else}
function fnUTF16ToUTF8(const sText :Unicodestring;
     InByteOrder :TByteOrder = tyLE):string;
{$endif}
 var
   ibyte :Int64;

begin
  Result := '';
  if sText <> '' then begin
    SetLength(Result,Length(sText)*3);
    ibyte := UTF16ToUTF8(sText,Pointer(Result),InByteOrder);
    if ibyte > 0 then
      SetLength(Result,ibyte)
    else
      Result := '';
  end;
end;

function fnUTF16ToUTF32(const sText :UnicodeString;
                       InByteOrder :TByteOrder = tyLE):UCS4String;
var
  iChar :Int64;

begin
  Result := nil;
  if sText <> '' then begin
    SetLength(Result,Length(sText));
    iChar := UTF16ToUTF32(sText,Pointer(Result),InByteOrder);
    if iChar > 0 then
      SetLength(Result,iChar)
    else
      Result := nil;
  end;
end;

function fnUTF32ToUTF16(constref sText :UCS4String;
   OutByteOrder :TByteOrder = tyLE):UnicodeString;

var
  iChar   :Int64;

begin
  Result := '';
  if Assigned(sText) then begin
    iChar := UTF32toUTF16Length(sText);
    if ichar > 0 then begin
      SetLength(Result,iChar);
      iChar := UTF32ToUTF16(sText,Pointer(Result),OutByteOrder);
      if iChar > 0 then
        SetLength(Result,iChar)
      else
        Result := '';
    end;
  end;
end;

{$IFDEF FPC_HAS_CPSTRING}
function fnUTF32ToUTF8(constref sText :UCS4String):Rawbytestring;
{$else}
function fnUTF32ToUTF8(constref sText :UCS4String):string;
{$endif}
var
  iByte :Int64;

begin
  Result := '';
  if Assigned(sText) then begin
    // count the byte length
    iByte := UTF32ToUTF8Length(sText);
    if iByte > 0 then begin
      SetLength(Result,iByte);
      iByte := UTF32ToUTF8(sText,Pointer(Result));
      if iByte > 0 then begin
        SetLength(Result,iByte);
        {$IFDEF FPC_HAS_CPSTRING}
          fnSetCodePage(@Result,65001);
        {$endif}
       end
      else
        Result := '';
    end;
  end;
end;

{$ENDIF CPUX86_64}

end.

