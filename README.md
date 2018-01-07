# checkMACRO.pl
check duplicated MACRO defined in c/c++ src code
for example, c/c++ code as below:

#ifdef MACRO1

#ifndef MACRO1

#endif

#endif

checkMACRO.pl will report "duplicated macro MACRO1 found " for the line "#ifndef MACRO1"
