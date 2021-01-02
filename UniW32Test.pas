(*
 This program is free software; you can do what you
 will.

 Copyright (c) 2018,2020 Klaus Stöhr

 This program is distributed in the hope that it will
 be useful, but WITHOUT ANY WARRANTY; without even the
 implied warranty of MERCHANTABILITY or FITNESS FOR A
 PARTICULAR PURPOSE.
*)
{$MODE objfpc}{$H+}
{$CODEPAGE UTF8}

program UniW32Test;

uses
  Sysutils,UniW32;

const
  dw128MB = 134217728;
  dw256MB = 268435456;
  dw512MB = 536870912;

var
  number :Integer;
  c :Char;

{$HINTS OFF}

procedure TestUTF8Error;
var
  i       :SizeInt;
  byWert  :pByte;
  sUni    :Unicodestring;
  sUTF8   :UTF8string;
  sText   :string;
  sUTF32  :UCS4string;

 begin
  Writeln(' ');
  Writeln('Test from UTF8 to UTF16 and UTF32');
  writeln('test for 1,2,3 and 4 byte coding.');
  writeln(' ');

  // this value are from unicode description version 11.0 or higher
  SetLength(sUTF8,36);
  byWert := pByte(sUTF8);

  byWert^ := Byte($C0);       // tab 3.8    9  char  8 error
  byWert  := ByWert + 1;
  byWert^ := Byte($AF);
  byWert  := ByWert + 1;
  byWert^ := Byte($E0);
  byWert  := ByWert + 1;
  byWert^ := Byte($80);
  byWert  := ByWert + 1;
  byWert^ := Byte($BF);
  byWert  := ByWert + 1;
  byWert^ := Byte($F0);
  byWert  := ByWert + 1;
  byWert^ := Byte($81);
  byWert  := ByWert + 1;
  byWert^ := Byte($81);
  byWert  := ByWert + 1;
  byWert^ := Byte($41);
  byWert  := ByWert + 1;

  byWert^ := Byte($ED);    // tab 3.9     9  Char  8 error
  byWert  := ByWert + 1;
  byWert^ := Byte($A0);
  byWert  := ByWert + 1;
  byWert^ := Byte($80);
  byWert  := ByWert + 1;
  byWert^ := Byte($ED);
  byWert  := ByWert + 1;
  byWert^ := Byte($BF);
  byWert  := ByWert + 1;
  byWert^ := Byte($BF);
  byWert  := ByWert + 1;
  byWert^ := Byte($ED);
  byWert  := ByWert + 1;
  byWert^ := Byte($AF);
  byWert  := ByWert + 1;
  byWert^ := Byte($41);
  byWert  := ByWert + 1;

  byWert^ := Byte($F4);    // tab 3.10    9   Char   7 error
  byWert  := ByWert + 1;
  byWert^ := Byte($91);
  byWert  := ByWert + 1;
  byWert^ := Byte($92);
  byWert  := ByWert + 1;
  byWert^ := Byte($93);
  byWert  := ByWert + 1;
  byWert^ := Byte($FF);
  byWert  := ByWert + 1;
  byWert^ := Byte($41);
  byWert  := ByWert + 1;
  byWert^ := Byte($80);
  byWert  := ByWert + 1;
  byWert^ := Byte($BF);
  byWert  := ByWert + 1;
  byWert^ := Byte($42);
  byWert  := ByWert + 1;

  byWert^ := Byte($E1);   //F   // tab 3.11   5 char  4 error
  byWert  := ByWert + 1;
  byWert^ := Byte($80);
  byWert  := ByWert + 1;
  byWert^ := Byte($E2);   //F
  byWert  := ByWert + 1;
  byWert^ := Byte($F0);   //F
  byWert  := ByWert + 1;
  byWert^ := Byte($91);
  byWert  := ByWert + 1;
  byWert^ := Byte($92);
  byWert  := ByWert + 1;
  byWert^ := Byte($F1);    //F
  byWert  := ByWert + 1;
  byWert^ := Byte($BF);
  byWert  := ByWert + 1;
  byWert^ := Byte($41);

{-------------------UTF8Length---------------------------------------}

  i := fnUTF8Length(sUTF8);
  writeln('Assembler routine UTF8Length');
  writeln('The UTF8string must have 32 Chars.');
  writeln('The UTF8string has ' + IntToStr(i) + ' Chars.');
  writeln(' ');

(*-----------------UTF8 to UTF16-------------------------------*)
  writeln('System routine UTF8 to UTF16LE');
  sUni := '';
  sUni  := system.UTF8Decode(sUTF8);
  sText := '';
  for i := 1 to Length(sUni) do begin
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  end;
  writeln(' ');
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF8 TO UTF16LE');
  sUni  := '';
  sUni  := UniW32.fnUTF8ToUTF16(sUTF8,tyLE);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF8 TO UTF16BE');
  sUni  := '';
  sUni  := UniW32.fnUTF8ToUTF16(sUTF8,tyBE);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');

(*-------------------UTF8 to UTF32--------------------------------*)
  writeln('Assembler UTF8 TO UTF32LE');
  sUTF32 := nil;
  sUTF32 := UniW32.fnUTF8ToUTF32(sUTF8);
  sText  := '';
  i := length(sUTF32);
  for i := 0 to Length(sUTF32)-2 do
    sText := sText + ' ' + IntToHex(SwapEndian(dword(sUTF32[i])),8);
  writeln(sText);
  writeln(' ');
end;

procedure TestUTF8;
var
  i       :SizeInt;
  byWert  :pByte;
  sUni    :Unicodestring;
  sUTF8   :UTF8string;
  sText   :UTF8string;
  sUTF32  :UCS4string;

 begin
  writeln('Test coding from UTF8 to UTF16 and UTF32');
  writeln('Test for 1,2,3 and 4 byte UTF8 coding.');
  writeln(' ');

 { UTF8 memory errors 29 chars (with BOM) }
  SetLength(sUTF8,56);
  byWert := pByte(sUTF8);

  byWert^ := Byte($EF);   //BOM
  byWert := ByWert + 1;
  byWert^ := Byte($BB);
  byWert := byWert + 1;
  byWert^ := Byte($BF);
  byWert := byWert + 1;

  byWert^ := Byte($79);   // U+0079
  byWert := ByWert + 1;

  byWert^ := Byte($C3);   // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($A4);
  byWert := byWert + 1;

  byWert^ := Byte($C0);   // Error
  byWert := ByWert + 1;
  byWert^ := Byte($C3);
  byWert := byWert + 1;

  byWert^ := Byte($C0);   // Error
  byWert := ByWert + 1;
  byWert^ := Byte($C3);
  byWert := byWert + 1;

  byWert^ := Byte($E2);   // U+20AC €
  byWert := ByWert + 1;
  byWert^ := Byte($82);
  byWert := byWert + 1;
  byWert^ := Byte($AC);
  byWert := byWert + 1;

  byWert^ := Byte($F0);   //Violinkey U+1D11E
  byWert := ByWert + 1;
  byWert^ := Byte($9D);
  byWert := byWert + 1;
  byWert^ := Byte($84);
  byWert := byWert + 1;
  byWert^ := Byte($9E);
  byWert := byWert + 1;

  byWert^ := Byte($ED);   // U+D000
  byWert := ByWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;

  byWert^ := Byte($ED);   // U+D7FF
  byWert := ByWert + 1;
  byWert^ := Byte($9F);
  byWert := byWert + 1;
  byWert^ := Byte($BF);
  byWert := byWert + 1;

  byWert^ := Byte($F0);   // U+10000
  byWert := ByWert + 1;
  byWert^ := Byte($90);
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;

  byWert^ := Byte($F4);   // U+100000
  byWert := ByWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;

  byWert^ := Byte($41);   // U+0041
  byWert := ByWert + 1;

  byWert^ := Byte($E2);   // U+2262
  byWert := ByWert + 1;
  byWert^ := Byte($89);
  byWert := byWert + 1;
  byWert^ := Byte($A2);
  byWert := ByWert + 1;

  byWert^ := Byte($EF);   // error mark  = 1 Char
  byWert := byWert + 1;
  byWert^ := Byte($BF);
  byWert := ByWert + 1;
  byWert^ := Byte($BD);
  byWert := ByWert + 1;

  byWert^ := Byte($EE);   // private zone
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := ByWert + 1;
  byWert^ := Byte($81);
  byWert := ByWert + 1;

  byWert^ := Byte($DF);   // error surrogate range
  byWert := byWert + 1;
  byWert^ := Byte($FF);
  byWert := ByWert + 1;

  byWert^ := Byte($61);
  byWert := ByWert + 1;

  byWert^ := Byte($F1);   // 4 byte sequence byte 4 not
  byWert := byWert + 1;
  byWert^ := Byte($80);
  byWert := ByWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;

  byWert^ := Byte($E1);  // 3 byte sequenz but solo 1 byte conform
  byWert := ByWert + 1;
  byWert^ := Byte($80);
  byWert := byWert + 1;

  byWert^ := Byte($C2);  // error folge byte not valid
  byWert := ByWert + 1;

  byWert^ := Byte($62);  // valid
  byWert := ByWert + 1;

  byWert^ := Byte($80);  // error
  byWert := byWert + 1;

  byWert^ := Byte($63);  // valid
  byWert := ByWert + 1;

  byWert^ := Byte($80);  // error
  byWert := ByWert + 1;

  byWert^ := Byte($BF);  // error
  byWert := byWert + 1;

  byWert^ := Byte($64);  // valid

(*---------------UTF8 to UTF16-------------------------------*)
  writeln('System routine UTF8 to UTF16 ');
  sUni := '';
  sUni  := system.UTF8Decode(sUTF8);
  sText := '';
  i := Length(sUni);
  for i := 1 to Length(sUni) do begin
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  end;
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF8 TO UTF16LE');
  sUni  := '';
  sUni  := UniW32.fnUTF8ToUTF16(sUTF8,tyLE);
  i := Length(sUni);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF8 TO UTF16BE');
  sUni  := '';
  sUni  := UniW32.fnUTF8ToUTF16(sUTF8,tyBE);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');


(*----------------UTF8 to UTF32--------------------------------*)
  writeln('Assembler UTF8 TO UTF32LE');
  sUTF32 := nil;
  sUTF32 := UniW32.fnUTF8ToUTF32(sUTF8);
  sText  := '';
  i := length(sUTF32);
  for i := 0 to Length(sUTF32)-2 do
    sText := sText + ' ' + IntToHex(SwapEndian(dword(sUTF32[i])),8);
  writeln(sText);
  writeln(' ');
end;

procedure TestUTF16;
 var
   i       :SizeInt;
   byWert  :pByte;
   sUniLE  :Unicodestring;
   sUniBE  :Unicodestring;
   sUTF8   :UTF8string;
   sText   :UTF8string;
   sUTF32  :UCS4string;

begin
  writeln('Test coding from UTF16 to UTF8 and UTF32');
  writeln('Test for 1,2,3 and 4 byte coding.');
  writeln(' ');
  {for surrogates must first see the high surrogate and then the low surrogate}
  (* UTF16LE memory *)
  SetLength(sUniLE,17);
  byWert := pByte(sUniLE);

  byWert^ := Byte($FF);    //BOM LE
  byWert := ByWert + 1;
  byWert^ := Byte($FE);
  byWert := byWert + 1;

  byWert^ := Byte($79);    // U+0079
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($E4);    // U+00E4
  byWert := ByWert + 1;    // -> ä $C3A4
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($FD);    // error marker
  byWert := ByWert + 1;
  byWert^ := Byte($FF);
  byWert := byWert + 1;

  byWert^ := Byte($06);    // Error
  byWert := ByWert + 1;    // -> low surrogate wish High surro!
  byWert^ := Byte($DC);
  byWert := byWert + 1;

  byWert^ := Byte($AC);   // U+20AC  € -> $E282AC
  byWert := ByWert + 1;
  byWert^ := Byte($20);
  byWert := byWert + 1;

  byWert^ := Byte($06);    // Error High surrogate but no low surrogate
  byWert := ByWert + 1;    // dito
  byWert^ := Byte($DB);
  byWert := byWert + 1;

  byWert^ := Byte($AC);   // U+20AC  € -> $E282AC
  byWert := ByWert + 1;
  byWert^ := Byte($20);
  byWert := byWert + 1;

  byWert^ := Byte($01);   // private zone
  byWert := ByWert + 1;      //->$EE8081
  byWert^ := Byte($E0);
  byWert := byWert + 1;

  byWert^ := Byte($34);   // High surro
  byWert := ByWert + 1;   //
  byWert^ := Byte($D8);
  byWert := byWert + 1;

  byWert^ := Byte($01);   // private zone
  byWert := ByWert + 1;
  byWert^ := Byte($E0);
  byWert := byWert + 1;

  byWert^ := Byte($1E);  // low surro
  byWert := ByWert + 1;
  byWert^ := Byte($DD);
  byWert := byWert + 1;

  byWert^ := Byte($53);   // U+24F5C surrogate
  byWert := ByWert + 1;
  byWert^ := Byte($D8);   // ->$F0A4BD9C
  byWert := byWert + 1;
  byWert^ := Byte($5C);
  byWert := ByWert + 1;
  byWert^ := Byte($DF);
  byWert := byWert + 1;

  byWert^ := Byte($41);   // U+0041
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($62);   // U+2262
  byWert := ByWert + 1;   // -> $E289A2
  byWert^ := Byte($22);
  byWert := byWert + 1;

  byWert^ := Byte($91);   // U+0391
  byWert := ByWert + 1;   // -> $CE91
  byWert^ := Byte($03);

  (* UTF16BE memory *)
  SetLength(sUniBE,17);
  byWert := pByte(sUniBE);

  byWert^ := Byte($FE);    //BOM BE
  byWert := ByWert + 1;
  byWert^ := Byte($FF);
  byWert := byWert + 1;

  byWert^ := Byte($00);    // U+0079
  byWert := ByWert + 1;
  byWert^ := Byte($79);
  byWert := ByWert + 1;

  byWert^ := Byte($00);    // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($E4);
  byWert := byWert + 1;

  byWert^ := Byte($FF);    // eror marker
  byWert := ByWert + 1;
  byWert^ := Byte($FD);
  byWert := byWert + 1;

  byWert^ := Byte($DC);    // Error
  byWert := ByWert + 1;
  byWert^ := Byte($06);
  byWert := byWert + 1;

  byWert^ := Byte($20);   // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($AC);
  byWert := byWert + 1;

  byWert^ := Byte($DB);    // Error
  byWert := ByWert + 1;
  byWert^ := Byte($06);
  byWert := byWert + 1;

  byWert^ := Byte($20);   // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($AC);
  byWert := byWert + 1;

  byWert^ := Byte($E0);   // private zone
  byWert := ByWert + 1;
  byWert^ := Byte($01);
  byWert := byWert + 1;

  byWert^ := Byte($D8);   // U+1D11E surrogate
  byWert := ByWert + 1;
  byWert^ := Byte($34);
  byWert := byWert + 1;

  byWert^ := Byte($E0);   // private zone
  byWert := ByWert + 1;
  byWert^ := Byte($01);
  byWert := byWert + 1;

  byWert^ := Byte($DD);
  byWert := ByWert + 1;
  byWert^ := Byte($1E);
  byWert := byWert + 1;

  byWert^ := Byte($D8);   // U+24F5C surrogate
  byWert := ByWert + 1;
  byWert^ := Byte($53);
  byWert := byWert + 1;
  byWert^ := Byte($DF);
  byWert := ByWert + 1;
  byWert^ := Byte($5C);
  byWert := byWert + 1;

  byWert^ := Byte($00);   // U+0041
  byWert := ByWert + 1;
  byWert^ := Byte($41);
  byWert := byWert + 1;

  byWert^ := Byte($22);   // U+2262
  byWert := ByWert + 1;
  byWert^ := Byte($62);
  byWert := byWert + 1;

  byWert^ := Byte($03);   // U+0391
  byWert := ByWert + 1;
  byWert^ := Byte($91);

(*------------------UTF16 to UTF8-------------------------------------*)
  writeln('System routine UTF16LE to UTF8');
  sUTF8 := '';
  sUTF8 := system.UTF8Encode(sUniLE);
  sText := '';
  if sUTF8 <> '' then begin
    for i := 1 to Length(sUTF8) do
      sText := sText + ' ' + IntToHex(Byte(sUTF8[i]),2);
  end;
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF16LE to UTF8');
  sUTF8 := '';
  sUTF8 := UniW32.fnUTF16ToUTF8(sUniLE,tyLE);
  sText := '';
  if sUTF8 <> '' then begin
    for i := 1 to Length(sUTF8) do
      sText := sText + ' ' + IntToHex(byte(sUTF8[i]),2);
  end;
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF16BE to UTF8');
  sUTF8 := '';
  sUTF8 := UniW32.fnUTF16ToUTF8(sUniBE,tyBE);
  sText := '';
  if sUTF8 <> '' then begin
    for i := 1 to Length(sUTF8) do
      sText := sText + ' ' + IntToHex(byte(sUTF8[i]),2);
  end;
  writeln(sText);
  writeln(' ');

(*----------------------UTF16 to UTF32-------------------------------*)
  writeln('System routine UTF16LE to UTF32LE');
  sUTF32 := nil;
  sUTF32 := system.UnicodeStringToUCS4String(sUniLE);
  sText  := '';
  if sUTF32 <> nil then begin
    for i := 0 to Length(sUTF32)-2 do
      sText := sText + ' ' + IntToHex(SwapEndian(dword(sUTF32[i])),8);
  end;
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF16LE to UTF32LE');
  sUTF32 := nil;
  sUTF32 := UniW32.fnUTF16ToUTF32(sUniLE,tyLE);
  sText  := '';
  if sUTF32 <> nil then begin
    for i := 0 to Length(sUTF32)-2 do
      sText := sText + ' ' + IntToHex(SwapEndian(dword(sUTF32[i])),8);
  end;
  writeln(sText);
  writeln(' ');

  writeln('assembler UTF16BE to UTF32LE');
  sUTF32 := nil;
  sUTF32 := UniW32.fnUTF16ToUTF32(sUniBE,tyBE);
  sText  := '';
  if sUTF32 <> nil then begin
    for i := 0 to Length(sUTF32)-2 do
      sText := sText + ' ' + IntToHex(SwapEndian(dword(sUTF32[i])),8);
  end;
  writeln(sText);
  writeln(' ');
end;


procedure TestUTF32;
 var
   i        :SizeInt;
   byWert   :pByte;
   sUni     :Unicodestring;
   sUTF8    :UTF8string;
   sText    :UTF8string;
   sUTF32LE :UCS4string;

begin
  writeln('Test coding from UTF32 to UTF8 and UTF16');
  writeln('Single test for 1,2,3 and 4 byte coding.');
  writeln(' ');

  (* UTF32 memory *)
  SetLength(sUTF32LE,14);     // is def as array and this start by 0
  byWert := pByte(sUTF32LE);

  byWert^ := Byte($FF);    //BOM LE
  byWert := ByWert + 1;
  byWert^ := Byte($FE);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($79);    //  U+0079
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($E4);    // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($FF);    // Error ill coding
  byWert := ByWert + 1;
  byWert^ := Byte($FF);
  byWert := byWert + 1;
  byWert^ := Byte($FF);
  byWert := ByWert + 1;
  byWert^ := Byte($02);
  byWert := ByWert + 1;

  byWert^ := Byte($FF);    // Error ill coding  surrogate range
  byWert := ByWert + 1;
  byWert^ := Byte($DB);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($E0);    // private zone
  byWert := ByWert + 1;
  byWert^ := Byte($01);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($FF);    // Error mark
  byWert := ByWert + 1;
  byWert^ := Byte($FD);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($AC);    // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($20);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($1E);    // U+1D11E
  byWert := ByWert + 1;
  byWert^ := Byte($D1);
  byWert := byWert + 1;
  byWert^ := Byte($01);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($5C);    // U+24F5C
  byWert := ByWert + 1;
  byWert^ := Byte($4F);
  byWert := byWert + 1;
  byWert^ := Byte($02);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($41);    // U+0041
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($62);    // U+2262
  byWert := ByWert + 1;
  byWert^ := Byte($22);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($91);    // U+0391
  byWert := ByWert + 1;
  byWert^ := Byte($03);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);

 (*---------------UTF32 to UTF8---------------------------------*)
  sUTF8  := '';
  sUTF8  := UniW32.fnUTF32ToUTF8(sUTF32LE);
  sText := '';
  for i := 1 to Length(sUTf8) do
    stext := sText + ' ' + IntToHex(byte(sUTF8[i]),2);
  writeln('Assembler UTF32LE to UTF8');
  writeln(sText);
  writeln(' ');

 (*----------------UTF32 to UTF16------------------------------*)
  writeln('System UTF32LE to UTF16LE');
  sUni  := '';
  sUni  := system.UCS4StringToUnicodeString(sUTF32LE);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF32LE to UTF16LE');
  sUni  := '';
  sUni  := UniW32.fnUTF32ToUTF16(sUTF32LE,tyLE);
  i := Length(sUni);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');

  writeln('Assembler UTF32LE to UTF16BE');
  sUni  := '';
  sUni  := UniW32.fnUTF32ToUTF16(sUTF32LE,tyBE);
  sText := '';
  for i := 1 to Length(sUni) do
    sText := sText + ' ' + IntToHex(SwapEndian(word(sUni[i])),4);
  writeln(sText);
  writeln(' ');
end;


(*--------------------Run Time tests--------------------------------*)
{
procedure TestUTF8Length;
 var
   sText,sTime   :string;
   i             :Integer;
   iSize         :PtrInt;
   StartZeit     :TTimestamp;
   Endzeit       :TTimestamp;
   Differenz     :Comp;
   Timer         :Comp;
   mSecsA,mSecsE :Comp;
   sAnzahl,sZeit :string;
   sUTF8         :string;
   byWert        :pByte;
   sTemp         :string;

begin
  writeln('The time is the average value for 5 rounds.');
  writeln(' ');
  writeln('Test a string with 1 GByte byte length');
  writeln('---------------------------------------------------- ');
  writeln('UTF8string with only 1 byte coding (ASCII)');
  writeln(' ');

  SetLength(sUTF8,dw1GB);
  try
    byWert := pByte(sUTF8);
    for i := 1 to dw1GB do begin
      byWert^ := Byte($79);
      byWert  := ByWert + 1;
    end;

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := UniW32.fnUTF8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer   := Timer / 5;
    sZeit   := FloatToStr(Timer);
    sAnzahl := IntToStr(iSize);
    writeln('Assembler routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
    writeln(' ');

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := LazUTF8.UTF8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(timer);
    sAnzahl := IntToStr(iSize);
    writeln('LazUTF8 Pascal routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
    writeln(' ');

  (* 2 byte Test *)
  writeln('---------------------------------------------');
  writeln('UTF8string with only 2 byte coding (512Mbyte)');
  writeln(' ');

    byWert := pByte(sUTF8);
    for i := 1 to dw512MB do begin
      byWert^ := Byte($C3);
      byWert := ByWert + 1;
      byWert^ := Byte($A4);
      byWert := byWert + 1;
    end;

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := UniW32.fnUtf8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(Timer);
    sAnzahl := IntToStr(iSize);
    writeln('Assembler routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
    writeln(' ');

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := LazUTF8.UTF8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(timer);
    sAnzahl := IntToStr(iSize);
    writeln('LazUTF8 Pascal routine');
    sText := 'the string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);

  (* 3-Byte Test *)
  sTemp := IntToStr(Length(sUTF8));
  writeln('---------------------------------------------');
  writeln('UTF8string with only 3 byte coding '+ '('+sTemp+' byte)');
  writeln(' ');

  byWert := pByte(sUTF8);
    for i := 1 to 357913941 do begin
      byWert^ := Byte($E2);
      byWert := ByWert + 1;
      byWert^ := Byte($82);
      byWert := byWert + 1;
      byWert^ := Byte($AC);
      byWert := byWert + 1;
    end;

    timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := UniW32.fnUtf8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(Timer);
    sAnzahl := IntToStr(iSize);
    writeln('Assembler routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
    writeln(' ');

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := LazUTF8.UTF8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(timer);
    sAnzahl := IntToStr(iSize);
    writeln('LazUTF8 Pascal routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);

  (* 4 byte Test *)
  writeln('----------------------------------------------');
  writeln('UTF8string with only 4 byte coding(256 MByte).');
  writeln(' ');

  byWert := pByte(sUTF8);
    for i := 1 to dw256MB do begin
      byWert^ := Byte($F0);
      byWert := ByWert + 1;
      byWert^ := Byte($9D);
      byWert := byWert + 1;
      byWert^ := Byte($84);
      byWert := byWert + 1;
      byWert^ := Byte($9E);
      byWert := byWert + 1;
    end;

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := UniW32.fnUtf8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(Timer);
    sAnzahl := IntToStr(iSize);
    writeln('Assembler routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
    writeln(' ');

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := LazUTF8.UTF8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(timer);
    sAnzahl := IntToStr(iSize);
    writeln('LazUTF8 Pascal routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);

  (* different byte test *)
  sTemp := IntToStr(Length(sUTF8));
  writeln('---------------------------------------------------');
  writeln('UTF8string with different codings'+'('+sTemp+' byte)');
  writeln(' ');

  byWert := pByte(sUTF8);
    for i := 1 to 67108864 do begin
      byWert^ := Byte($E2);
      byWert := ByWert + 1;
      byWert^ := Byte($82);
      byWert := byWert + 1;
      byWert^ := Byte($AC);
      byWert := byWert + 1;

      byWert^ := Byte($79);
      byWert := ByWert + 1;

      byWert^ := Byte($C3);
      byWert := ByWert + 1;
      byWert^ := Byte($A4);
      byWert := byWert + 1;

      byWert^ := Byte($79);
      byWert := ByWert + 1;

      byWert^ := Byte($F0);
      byWert := ByWert + 1;
      byWert^ := Byte($9D);
      byWert := byWert + 1;
      byWert^ := Byte($84);
      byWert := byWert + 1;
      byWert^ := Byte($9E);
      byWert := byWert + 1;

      byWert^ := Byte($C3);
      byWert := ByWert + 1;
      byWert^ := Byte($A4);
      byWert := byWert + 1;

      byWert^ := Byte($E2);
      byWert := ByWert + 1;
      byWert^ := Byte($82);
      byWert := byWert + 1;
      byWert^ := Byte($AC);
      byWert := byWert + 1;
    end;

    timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := UniW32.fnUtf8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(Timer);
    sAnzahl := IntToStr(iSize);
    writeln('Assembler routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
    writeln(' ');

    Timer := 0;
    for i := 1 to 5 do begin
      StartZeit := DateTimeToTimestamp(Time);
      iSize     := LazUTF8.UTF8Length(sUTF8);
      EndZeit   := DateTimetoTimeStamp(Time);
      mSecsE    := TimeStampToMSecs(Endzeit);
      mSecsA    := TimeStampToMSecs(StartZeit);
      Differenz := mSecsE - msecsA;
      Timer     := Timer + Differenz;
    end;
    Timer := Timer / 5;
    sZeit := FloatToStr(timer);
    sAnzahl := IntToStr(iSize);
    writeln('LazUTF8 Pascal routine');
    sText := 'The string is ' + sAnzahl + ' chars.';
    sTime := 'Time for search: ' + sZeit + ' milliseconds';
    writeln(sText);
    writeln(sTime);
  finally
    sUTF8 := '';
  end;
end;
}

procedure TestUTF8ToUTF16;
 var
   sTime        :string;
   i            :Integer;
   StartZeit    :TTimestamp;
   Endzeit      :TTimestamp;
   Differenz    :Comp;
   timer        :Comp;
   mSecsA,mSecsE :Comp;
   sZeit         :string;
   byWert       :pByte;
   sUni         :Unicodestring;
   sUTF8        :string;

begin
  writeln('The time is the average value for 5 rounds of test.');
  writeln(' ');
  writeln('---------------------------------------');
  writeln('Test from UTF8 to UTF16');
  writeln('for a 512 MB UTF8string');
  writeln(' ');

  (* UTF8 memory *)
  SetLength(sUTF8,dw512MB);  // 512 MB
  byWert  := pByte(sUTF8);
  byWert^ := Byte($EF);   //BOM
  byWert  := ByWert + 1;
  byWert^ := Byte($BB);
  byWert  := byWert + 1;
  byWert^ := Byte($BF);
  byWert  := byWert + 1;

  for i := 1 to 29826161 do begin
    byWert^ := Byte($79);   // U+0079
    byWert := ByWert + 1;

    byWert^ := Byte($C3);   // U+00E4
    byWert := ByWert + 1;
    byWert^ := Byte($A4);
    byWert := byWert + 1;

    byWert^ := Byte($EF);   // U+20AC
    byWert := ByWert + 1;
    byWert^ := Byte($BF);
    byWert := byWert + 1;
    byWert^ := Byte($BF);
    byWert := byWert + 1;

    byWert^ := Byte($F0);   //Violinkey U+1D11E
    byWert := ByWert + 1;
    byWert^ := Byte($9D);
    byWert := byWert + 1;
    byWert^ := Byte($84);
    byWert := byWert + 1;
    byWert^ := Byte($9E);
    byWert := byWert + 1;

    byWert^ := Byte($F4);   // U+100001
    byWert := ByWert + 1;
    byWert^ := Byte($80);
    byWert := byWert + 1;
    byWert^ := Byte($80);
    byWert := byWert + 1;
    byWert^ := Byte($81);
    byWert := byWert + 1;

    byWert^ := Byte($41);   // U+0041
    byWert := ByWert + 1;

    byWert^ := Byte($E2);   // U+2262
    byWert := ByWert + 1;
    byWert^ := Byte($89);
    byWert := byWert + 1;
    byWert^ := Byte($A2);
    byWert := byWert + 1;
  end;
  byWert^ := Byte($79);   // U+0079
  byWert := ByWert + 1;

  byWert^ := Byte($C3);   // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($A4);
  byWert := byWert + 1;

  byWert^ := Byte($E2);   // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($82);
  byWert := byWert + 1;
  byWert^ := Byte($AC);
  byWert := byWert + 1;

  byWert^ := Byte($F0);   //Violinkey U+1D11E
  byWert := ByWert + 1;
  byWert^ := Byte($9D);
  byWert := byWert + 1;
  byWert^ := Byte($84);
  byWert := byWert + 1;
  byWert^ := Byte($9E);
  byWert := byWert + 1;

  byWert^ := Byte($41);   // U+0041

  writeln('Assembler routine');
  timer := 0;
  for i := 1 to 5 do begin
    sUni := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUni      := UniW32.fnUTF8ToUTF16(sUTF8,tyLE);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sTime := IntToStr(Length(sUni));
  sZeit := 'string length in char - BOM:' + sTime;
  writeln(sZeit);
  writeln(' ');

  writeln('System routine');
  timer := 0;
  for i := 1 to 5 do begin
    sUni := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUni      := system.UTF8Decode(sUTF8);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(timer);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sTime := IntToStr(Length(sUni));
  sZeit := 'string length in char + BOM:' + sTime;
  writeln(sZeit);
  writeln(' ');
end;

procedure TestUTF8ToUTF32;
  var
    i                 :dword;
    mSecA             :Comp;
    mSecE             :Comp;
    StartZeit         :TTimestamp;
    EndZeit           :TTimeStamp;
    Timer             :double;
    Differenz         :Comp;
    sZeit             :string;
    sTime             :string;
    sUTF32            :UCS4String;
    sUTF8             :UTF8string;
    byWert            :pByte;

begin
  writeln('The time is the average value for 5 rounds of test.');
  writeln(' ');
  writeln('---------------------------------------');
  writeln('Test from UTF8 to UTF32');
  writeln('for a 512 MB UTF8string');
  writeln(' ');

  (* UTF8 memory *)
  SetLength(sUTF8,dw512MB);  // 512 MB

  byWert  := pByte(sUTF8);
  byWert^ := Byte($EF);   //BOM
  byWert  := ByWert + 1;
  byWert^ := Byte($BB);
  byWert  := byWert + 1;
  byWert^ := Byte($BF);
  byWert  := byWert + 1;

  for i := 1 to 29826161 do begin
    byWert^ := Byte($79);   // U+0079
    byWert := ByWert + 1;

    byWert^ := Byte($C3);   // U+00E4
    byWert := ByWert + 1;
    byWert^ := Byte($A4);
    byWert := byWert + 1;

    byWert^ := Byte($E2);   // U+20AC
    byWert := ByWert + 1;
    byWert^ := Byte($82);
    byWert := byWert + 1;
    byWert^ := Byte($AC);
    byWert := byWert + 1;

    byWert^ := Byte($F0);   //Violinkey U+1D11E
    byWert := ByWert + 1;
    byWert^ := Byte($9D);
    byWert := byWert + 1;
    byWert^ := Byte($84);
    byWert := byWert + 1;
    byWert^ := Byte($9E);
    byWert := byWert + 1;

    byWert^ := Byte($F4);   // U+100001
    byWert := ByWert + 1;
    byWert^ := Byte($80);
    byWert := byWert + 1;
    byWert^ := Byte($80);
    byWert := byWert + 1;
    byWert^ := Byte($81);
    byWert := byWert + 1;

    byWert^ := Byte($41);   // U+0041
    byWert := ByWert + 1;

    byWert^ := Byte($E2);   // U+2262
    byWert := ByWert + 1;
    byWert^ := Byte($89);
    byWert := byWert + 1;
    byWert^ := Byte($A2);
    byWert := byWert + 1;
  end;
  byWert^ := Byte($79);   // U+0079
  byWert := ByWert + 1;

  byWert^ := Byte($C3);   // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($A4);
  byWert := byWert + 1;

  byWert^ := Byte($E2);   // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($82);
  byWert := byWert + 1;
  byWert^ := Byte($AC);
  byWert := byWert + 1;

  byWert^ := Byte($F0);   //Violinkey U+1D11E
  byWert := ByWert + 1;
  byWert^ := Byte($9D);
  byWert := byWert + 1;
  byWert^ := Byte($84);
  byWert := byWert + 1;
  byWert^ := Byte($9E);
  byWert := byWert + 1;

  byWert^ := Byte($41);   // U+0041

  writeln('Assembler routine');
  Timer := 0;
  for i := 1 to 5 do begin
    sUTF32      := nil;
    StartZeit   := DateTimeToTimestamp(Time);
    sUTF32      := UniW32.fnUTF8ToUTF32(sUTF8);
    EndZeit     := DateTimetoTimeStamp(Time);
    mSecE       := TimeStampToMSecs(Endzeit);
    mSecA       := TimeStampToMSecs(StartZeit);
    Differenz   := mSecE - mSecA;
    Timer       := Timer + Differenz;
  end;
  Timer := Timer / 5;
  i := Trunc(Timer);
  sZeit := IntToStr(i);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sTime := IntToStr(Length(sUTF32));
  sZeit := 'string length in char - BOM:' + sTime;
  writeln(sZeit);
  writeln(' ');
end;


(*--------------------UTF16--------------------------------------------*)

procedure TestUTF16ToUTF8;
 var
   sTime,sZeit  :string;
   i            :Integer;
   StartZeit    :TTimestamp;
   Endzeit      :TTimestamp;
   Differenz    :Comp;
   timer        :Comp;
   mSecsA,mSecsE :Comp;
   byWert       :pByte;
   sUni         :unicodestring;
   sUTF8        :UTF8string;

begin
  writeln('The time is the average value for 5 rounds of test.');
  writeln(' ');
  writeln('---------------------------------------');
  writeln('Test from UTF16 to UTF8');
  writeln('for a 512 MB Unicodestring');
  writeln(' ');

  (* UTF16 memory *)
  SetLength(sUni,dw256MB);  // Unicode 2 Chars-> 512 MB

  byWert := PByte(sUni);
  byWert^ := Byte($FF);  // BOM
  byWert := ByWert + 1;
  byWert^ := Byte($FE);
  byWert := ByWert + 1;

  for i := 1 to 26843545 do begin
    byWert^ := Byte($79);  // U+0079
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := ByWert + 1;

    byWert^ := Byte($E4);  // U+00E4
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($AC);  // U+20AC
    byWert := ByWert + 1;
    byWert^ := Byte($20);
    byWert := byWert + 1;

    byWert^ := Byte($34);  // U+1D11E surrogate
    byWert := ByWert + 1;
    byWert^ := Byte($D8);
    byWert := byWert + 1;
    byWert^ := Byte($1E);
    byWert := byWert + 1;
    byWert^ := Byte($DD);
    byWert := byWert + 1;

    byWert^ := Byte($53);  // U+24F5C surrogate
    byWert := ByWert + 1;
    byWert^ := Byte($D8);
    byWert := byWert + 1;
    byWert^ := Byte($5C);
    byWert := byWert + 1;
    byWert^ := Byte($DF);
    byWert := byWert + 1;

    byWert^ := Byte($41);  // U+0041
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($62);  // U+2261
    byWert := ByWert + 1;
    byWert^ := Byte($22);
    byWert := byWert + 1;

    byWert^ := Byte($91);  // U+0391
    byWert := ByWert + 1;
    byWert^ := Byte($03);
    byWert := byWert + 1;
  end;
  byWert^ := Byte($79);  // U+0079
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($E4);  // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($AC);  // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($20);
  byWert := byWert + 1;

  byWert^ := Byte($34);  // U+1D11E surrogate
  byWert := ByWert + 1;
  byWert^ := Byte($D8);
  byWert := byWert + 1;
  byWert^ := Byte($1E);
  byWert := byWert + 1;
  byWert^ := Byte($DD);

  writeln('Assembler routine');
  timer := 0;
  for i := 1 to 5 do begin
    sUTF8 := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUTF8     := UniW32.fnUTF16ToUTF8(sUni,tyLE);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sTime := IntToStr(Length(sUTF8));
  sZeit := 'string length in byte - BOM: ' + sTime;
  writeln(sZeit);
  writeln(' ');

  writeln('system routine');
  Timer := 0;
  for i := 1 to 5 do begin
    sUTF8     := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUTF8     := system.UTF8Encode(sUni);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sTime := IntToStr(Length(sUTF8));
  sZeit := 'string length in byte + BOM: ' + sTime;
  writeln(sZeit);
  writeln(' ');
end;


procedure TestUTF16ToUTF32;
 var
   sTime        :string;
   i            :Integer;
   StartZeit    :TTimestamp;
   Endzeit      :TTimestamp;
   Differenz    :Comp;
   timer        :Comp;
   mSecsA,mSecsE:Comp;
   sZeit        :string;
   sText        :string;
   byWert       :pByte;
   sUni         :Unicodestring;
   sUTF32       :UCS4string;

begin
  writeln('The time is the average value for 5 rounds of test.');
  writeln(' ');
  writeln('---------------------------------------');
  writeln('Test from UTF16 to UTF32');
  writeln('for a 512 MB Unicodestring');
  writeln(' ');

  (* UTF16 memory *)
  SetLength(sUni,dw256MB);  // Unicode 2 Chars 256 MB

  byWert := PByte(sUni);
  byWert^ := Byte($FF);  // BOM
  byWert := ByWert + 1;
  byWert^ := Byte($FE);
  byWert := ByWert + 1;

  for i := 1 to 26843545 do begin
    byWert^ := Byte($79);  // U+0079
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := ByWert + 1;

    byWert^ := Byte($E4);  // U+00E4
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($AC);  // U+20AC
    byWert := ByWert + 1;
    byWert^ := Byte($20);
    byWert := byWert + 1;

    byWert^ := Byte($34);  // U+1D11E surrogate
    byWert := ByWert + 1;
    byWert^ := Byte($D8);
    byWert := byWert + 1;
    byWert^ := Byte($1E);
    byWert := byWert + 1;
    byWert^ := Byte($DD);
    byWert := byWert + 1;

    byWert^ := Byte($53);  // U+24F5C surrogate
    byWert := ByWert + 1;
    byWert^ := Byte($D8);
    byWert := byWert + 1;
    byWert^ := Byte($5C);
    byWert := byWert + 1;
    byWert^ := Byte($DF);
    byWert := byWert + 1;

    byWert^ := Byte($41);  // U+0041
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($62);  // U+2261
    byWert := ByWert + 1;
    byWert^ := Byte($22);
    byWert := byWert + 1;

    byWert^ := Byte($91);  // U+0391
    byWert := ByWert + 1;
    byWert^ := Byte($03);
    byWert := byWert + 1;
  end;
  byWert^ := Byte($79);  // U+0079
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;

  byWert^ := Byte($E4);  // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($AC);  // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($20);
  byWert := byWert + 1;

  byWert^ := Byte($34);  // U+1D11E surrogate
  byWert := ByWert + 1;
  byWert^ := Byte($D8);
  byWert := byWert + 1;
  byWert^ := Byte($1E);
  byWert := byWert + 1;
  byWert^ := Byte($DD);

  writeln('Assembler routine');
  Timer := 0;
  for i := 1 to 5 do begin
    sUTF32    := nil;
    StartZeit := DateTimeToTimestamp(Time);
    sUTF32    := UniW32.fnUtf16ToUTF32(sUni);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sText := 'string length in char - BOM:' + IntToStr(length(sUTF32));
  writeln(sText);
  writeln(' ');

  writeln('System routine');
  Timer := 0;
  for i := 1 to 5 do begin
    sUTF32    := nil;
    StartZeit := DateTimeToTimestamp(Time);
    sUTF32    := system.UnicodeStringToUCS4String(sUni);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(timer);
  sTime := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sTime);
  sText := 'string length in char + BOM:' + IntToStr(Length(sUTF32));
  writeln(sText);
  writeln(' ');
end;

procedure TestUTF32toUTF8;
 var
   i            :Integer;
   StartZeit    :TTimestamp;
   Endzeit      :TTimestamp;
   Differenz    :Comp;
   timer        :Comp;
   mSecsA,mSecsE:Comp;
   sZeit        :string;
   sText        :string;
   byWert       :pByte;
   sUTF8        :string;
   sUTF32       :UCS4string;


begin
  writeln('The time is the average value for 5 rounds of test.');
  writeln(' ');
  writeln('---------------------------------------');
  writeln('Test from UTF32LE to UTF8');
  writeln('for a 512 MB UCS4string (Byte not char!)');
  writeln(' ');

  SetLength(sUTF32,dw128MB+1);

  byWert := PByte(sUTF32);
  byWert^ := Byte($FF);  // BOM     3 Byte
  byWert := ByWert + 1;
  byWert^ := Byte($FE);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  for i := 1 to 3728270 do begin
    byWert^ := Byte($79);  // U+0079  1Byte
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($E4);  // U+00E4   2Byte
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($AC);  // U+20AC   3Byte
    byWert := ByWert + 1;
    byWert^ := Byte($20);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($1E);  // U+1D11E surrogate   4 Byte
    byWert := ByWert + 1;
    byWert^ := Byte($D1);
    byWert := byWert + 1;
    byWert^ := Byte($01);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($5C);  // U+24F5C surrogate  4 Byte
    byWert := ByWert + 1;
    byWert^ := Byte($4F);
    byWert := byWert + 1;
    byWert^ := Byte($02);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($41);  // U+0041    1 Byte
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($62);  // U+2261   3 Byte
    byWert := ByWert + 1;
    byWert^ := Byte($22);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($91);  // U+0391   2 Byte
    byWert := ByWert + 1;
    byWert^ := Byte($03);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($5C);  // U+D55C   3 Byte
    byWert := ByWert + 1;
    byWert^ := Byte($D5);
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
  end;

  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);

  writeln('Assembler routine');
  Timer := 0;
  for i := 1 to 5 do begin
    sUTF8     := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUTF8     := UniW32.fnUTF32ToUTF8(sUTF32);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sText := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sText);
  sText := 'string length in Byte - BOM:' + IntToStr(Length(sUTF8));
  writeln(sText);
  writeln(' ');
end;

procedure TestUTF32toUTF16;
 var
   i            :Integer;
   StartZeit    :TTimestamp;
   Endzeit      :TTimestamp;
   Differenz    :Comp;
   timer        :Comp;
   mSecsA,mSecsE:Comp;
   sZeit        :string;
   sText        :string;
   byWert       :pByte;
   sUni         :Unicodestring;
   sUTF32       :UCS4string;

begin
  writeln('The time is the average value for 5 rounds of test.');
  writeln(' ');
  writeln('---------------------------------------');
  writeln('Test from UTF32LE to UTF16LE');
  writeln('for a 512 MB UCS4string (Byte not char!)');
  writeln(' ');

  SetLength(sUTF32,dw128MB+1);
  i := Length(sUTF32);

  byWert := PByte(sUTF32);
  byWert^ := Byte($FF);  // BOM
  byWert := ByWert + 1;
  byWert^ := Byte($FE);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  for i := 1 to 14913080 do begin //3728270 do begin
    byWert^ := Byte($79);  // U+0079
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($E4);  // U+00E4
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($AC);  // U+20AC
    byWert := ByWert + 1;
    byWert^ := Byte($20);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($1E);  // U+1D11E surrogate
    byWert := ByWert + 1;
    byWert^ := Byte($D1);
    byWert := byWert + 1;
    byWert^ := Byte($01);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($5C);  // U+24F5C surrogate
    byWert := ByWert + 1;
    byWert^ := Byte($4F);
    byWert := byWert + 1;
    byWert^ := Byte($02);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($41);  // U+0041
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($62);  // U+2261
    byWert := ByWert + 1;
    byWert^ := Byte($22);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($91);  // U+0391
    byWert := ByWert + 1;
    byWert^ := Byte($03);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;

    byWert^ := Byte($5C);  // U+D55C
    byWert := ByWert + 1;
    byWert^ := Byte($D5);
    byWert := ByWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
    byWert^ := Byte($00);
    byWert := byWert + 1;
  end;
  byWert^ := Byte($79);  // U+0079
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($E4);  // U+00E4
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($AC);  // U+20AC
  byWert := ByWert + 1;
  byWert^ := Byte($20);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($1E);  // U+1D11E surrogate
  byWert := ByWert + 1;
  byWert^ := Byte($D1);
  byWert := byWert + 1;
  byWert^ := Byte($01);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($62);  // U+2261
  byWert := ByWert + 1;
  byWert^ := Byte($22);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($91);  // U+0391
  byWert := ByWert + 1;
  byWert^ := Byte($03);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;

  byWert^ := Byte($5C);  // U+D55C
  byWert := ByWert + 1;
  byWert^ := Byte($D5);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);

  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := ByWert + 1;
  byWert^ := Byte($00);
  byWert := byWert + 1;
  byWert^ := Byte($00);

  writeln('Assembler routine');
  Timer := 0;
  for i := 1 to 5 do begin
    sUni      := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUni      := UniW32.fnUTF32ToUTF16(sUTF32,tyLE);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sText := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sText);
  sText := '';
  sText := 'string length in Char - BOM:' + IntToStr(Length(sUni));
  writeln(sText);
  writeln(' ');

  writeln('system routine');
  Timer := 0;
  i := Length(sUni);
  for i := 1 to 5 do begin
    sUni      := '';
    StartZeit := DateTimeToTimestamp(Time);
    sUni      := system.UCS4stringtoUnicodestring(sUTF32);
    EndZeit   := DateTimetoTimeStamp(Time);
    mSecsE    := TimeStampToMSecs(Endzeit);
    mSecsA    := TimeStampToMSecs(StartZeit);
    Differenz := mSecsE - msecsA;
    Timer     := Timer + Differenz;
  end;
  i := Length(sUni);
  Timer := Timer / 5;
  sZeit := FloatToStr(Timer);
  sText := 'Time for coding: ' + sZeit + ' milliseconds';
  writeln(sText);
  sText := 'string length in Char+ BOM:' + IntToStr(Length(sUni));
  writeln(sText);
  writeln(' ');
end;


begin
  writeln('               Coding tests');
  writeln('UTF8error;               input = 1');
  writeln('UTF8 to UTF16 and UTF32; input = 2');
  writeln('UTF16 to UTF8 and UTF32; input = 3');
  writeln('UTF32 to UTF8 and UTF16; input = 4');
  writeln(' ');
  writeln('              Runtime tests');
  writeln('TestUTF8toUTF16;  input = 10');
  writeln('TestUTF8toUTF32;  input = 11');
  writeln('TestUTF16toUTF8;  input = 12');
  writeln('TestUTF16toUTF32; input = 13');
  writeln('TestUTF32ToUTF16; input = 14');
  writeln('TestUTF32toUTF8;  input = 15');
  writeln(' ');
  writeln('which test you will start?');
  readln(number);
  case number of
    1: TestUTF8error;
    2: TestUTF8;
    3: TestUTF16;
    4 :TestUTF32;
    10: TestUTF8toUTF16;
    11: TestUTF8toUTF32;
    12: TestUTF16toUTF8;
    13: TestUTF16toUTF32;
    14: TestUTF32ToUTF16;
    15: TestUTF32toUTF8;
  end;

 writeln('press Enter for end');
 read(c);
end.

