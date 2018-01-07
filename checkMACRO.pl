#!/usr/bin/perl -w

#check duplicated macro in C/C++ file
#including *.c *.h *.cpp *.hpp *.cc

use Getopt::Long;


#add starting time and end time, and how many time it cost

my $finddir = "./";  #default set to current dir
my @filelist = undef;  # get filelist by find command from current directory or from ARGV
my %ifdefhash = undef; #contains all ifdef MACROs found so far in currently handled file
my $definedMacro = undef; # contains the all MACRO bits found so far
my $macroLevel = 0; # check macro level incase of error pairing
my $macroCount = 0; # how many macros found in current file so far
my $arrayMacro = undef; #arrayMacro to store macro already defined

my $inComment = 0;
my $lineNum = 0;
my $curFile = undef;
my $tempMacro = "MACRO";
my $debug = 0;  #debug flag if it's set, debug log will be printed
my $help = 0;  #help flag if it's set, usage info will be printed

# remove comment, get the only useful source code from a line
sub getRealSrc
{
    my @realSrc=undef;
    my $tmpline = $_[0];
    my @letters = split (//, $tmpline);
    my $letterCount = @letters;
    my $curLetterId = 0;
    while($curLetterId < ($letterCount-1))
    {
        my $inChar = $letters[$curLetterId];
        if (( $inComment == 1 ) && (( $curLetterId >= ($letterCount - 1))))
        {
            $inComment = 0;
            last;
        }
        elsif (( $inComment == 1) && ($inChar eq "*") && ($letters[$curLetterId+1] eq "/"))
        {
            $inComment = 0;
            $curLetterId++;
            $curLetterId++;
        }
        elsif ( $inComment == 1)
        {
            $curLetterId++;
        }
        elsif(( $inChar eq "/") && ( $letters[$curLetterId+1] eq "/") )
        {
            $inComment = 0;
            $curLetterId++;
            $curLetterId++;
            last;
        }
        elsif(( $inChar eq "/") && ( $letters[$curLetterId+1] eq "*") )
        {
            $inComment = 1;
            $curLetterId++;
            $curLetterId++;
        }
        else
        {
            push (@realSrc, $inChar);
            $curLetterId++;
        }
    }

    if ( @realSrc )
    {
        return join('',@realSrc);
    }
    else
    {
        return undef;
    }

}

sub getMacro
{
   my $tmplinereturn = getRealSrc(@_);
   #remov space at the begining and end of the src string
  
   if ($tmplinereturn)
   {
       $tmplinereturn =~ s/^\s+|\s+$//g;
       $_ = $tmplinereturn;
      if(/^#ifdef/ || /^#ifndef/ || /^#endif/ || /^#if/)
      {
         return $tmplinereturn;
      }
   }
   return undef;

}

sub checkMacroInFile  #main function handles the duplicated macros
{
    open DEFINFILE, $_[0];
    $definedMacro = 0;
    $macroCount = 0;
    %ifdefhash = ();
    my $realmacrosrc = undef;
    while( my $line = <DEFINFILE> ) {
        print_debug("line=$line");
        $lineNum = $.;
        $_ = $line;
        $realmacrosrc= undef;
        unless(/#if/ || /\/\// || /\/\*/ || /\*\// || /#endif/)
        {
            $realmacrosrc = undef;
            next;
        }
        $realmacrosrc = getMacro($line); 
        $_ = $realmacrosrc;
        unless ( $realmacrosrc )
        {
            next;
        }
        $_ = $realmacrosrc;
        if(/^#ifdef/ || /^#ifndef/)
        {
            #$`$&$'
            $_ = $';
            if(/\w+/)  #[a-zA-Z0-9]+  find the macro after ifdef or ifndef
            {
                $currentMacro = $&;
            }
            else
            {
                print "FATAL ERROR in sub checkMacroInFile when trying to get currentMacro in file $curFile\n";
                last;
            }
            $macroLevel++;
            my $i = 0;
            for($i = 0; $i < $macroLevel-1; $i++)
            {
                print_debug("=="); #help to debug macro level
            }
            print_debug("$realmacrosrc REPORTOUT\n");
            print_debug("macroLevel = $macroLevel, currentMacro=$currentMacro\n");
            my $currentBit;
            if ( exists $ifdefhash{$currentMacro} )
            {
                $currentBit = $ifdefhash{$currentMacro};
                if ( $definedMacro & $currentBit)
                {
                    print_debug("$definedMacro, $currentBit\n");
                    print "REPORT: duplicated macro $currentMacro found at line: $lineNum in file: $curFile";
                    $currentMacro = "DUPLICATED";
                }
                else
                {
                    print_debug("$definedMacro, $currentBit before\n");
                    $definedMacro |= $currentBit;
                    print_debug("$definedMacro, $currentBit after\n");
                }
            }
            else
            {
                print_debug("ADDMACRO macroCount = $macroCount\n");
                $ifdefhash{$currentMacro} = 2 ** $macroCount++;
                print_debug("ifhdefhash(currentMacro) = $ifdefhash{$currentMacro}\n");
                print_debug("$definedMacro, currentMacro = $currentMacro before\n");
                $definedMacro |= $ifdefhash{$currentMacro};
                print_debug("$definedMacro, currentMacro = $currentMacro\n");
                
            }
            push(@arrayMacro, $currentMacro);
    
        } elsif (/^#endif/){
            $tempMacro = undef;
            $tempMacro = pop (@arrayMacro);
            if( !$tempMacro )
            {
                print "FATAL ERROR arrayMacro is empty\n";
		last;
            }
            elsif( ( $tempMacro eq "DUPLICATED" ) || ( $tempMacro eq "UNDEFINEDMACRO" ))
            {
                print_debug("pop out DUPLICATED/UNDEFINEDMACRO macro\n");
            }
            else
            {
                print_debug("debug tempMacro = $tempMacro\n");
                if(exists $ifdefhash{$tempMacro})
                {
                    print_debug("debug definedMacro = $definedMacro, $ifdefhash{$tempMacro}\n");
                    $definedMacro ^= $ifdefhash{$tempMacro};
                    print_debug("debug definedMacro = $definedMacro after\n");
                }
            }
            my $i = 0;
            for($i = 0; $i < $macroLevel-1; $i++)
            {
                print_debug("==");
            }
            print_debug("#endif REPORTOUT definedMacro=$definedMacro tempMacro=$tempMacro\n");
            $macroLevel--;
            if ($macroLevel < 0)
            {
                print "REPORT FATAL ERROR: macroLevel = $macroLevel \n";
		last;
            }

        } elsif (/^#if/) { #if(defined LIGHT_RADIO || defined LTE_FRAME_TYPE_2)
            $currentMacro = "UNDEFINEDMACRO";
            $macroLevel++;
            #$`$&$'
            $_ = $';
            my $i = 0;
            for($i = 0; $i < $macroLevel-1; $i++)
            {
                print_debug("==");
            }
            print_debug("$realmacrosrc REPORTOUT\n");
            if(/defined/)
            {
                $_ = $';
                #if defined macro1 && defined macro2
                #if(defined A && defined B)
                #if (MAX && !MIN)
                #if defined(A) && defined(B)
                #if defined BUFSIZE && BUFSIZE >= 1024 conditionals
                #if defined (__vax__) || defined (__ns16000__)
                if (/\&\&/)
                {
                    $_ = $';
                    if(/defined/)
                    {
                        $_ = $';
                        if(/\w+/)  #[a-zA-Z0-9]+  find the second macro
                        {
                            $currentMacro = $&;
                            if ( exists $ifdefhash{$currentMacro} )
                            {
                                if ( $definedMacro & $currentBit)
                                {
				     $currentMacro = "DUPLICATED";
                                     print_debug("$definedMacro, $currentBit\n");
                                     print "REPORT: duplicated macro found for complex macro at line: $lineNum in file: $curFile";
                                }
                                else
                                {
                                     $currentBit = $ifdefhash{$currentMacro};
                                     $definedMacro |= $ifdefhash{$currentMacro};
                                     
                                }
                            }
                        }
                    }
                }
                elsif (/\|\|/) #cannot handle such case
                {
		    $currentMacro = "UNDEFINEDMACRO";
                }
                else #for case: if defined macro
                {
                    if(/\w+/)  #[a-zA-Z0-9]+ 
                    {
                        $currentMacro = $&;
                        print_debug("debug currentMacro=$currentMacro\n");
                        if ( exists $ifdefhash{$currentMacro} )
                        {
                            $currentBit = $ifdefhash{$currentMacro};
                            if ( $definedMacro & $currentBit)
                            {
				$currentMacro = "DUPLICATED";
                                print "$definedMacro, $currentBit\n";
                                print "REPORT: duplicated macro $currentMacro found at line: $lineNum in file: $curFile";
                            }
                            else
                            {
                                $definedMacro |= $currentBit;
                            }
                        }
                        else
                        {
                            print_debug("ADDMACRO macroCount = $macroCount\n");
                            $ifdefhash{$currentMacro} = 2 ** $macroCount++;
                            print_debug("ifhdefhash(currentMacro) = $ifdefhash{$currentMacro}\n");
                            print_debug("$definedMacro, currentMacro = $currentMacro before\n");
                            $definedMacro |= $ifdefhash{$currentMacro};
                            print_debug("$definedMacro, currentMacro = $currentMacro\n");
                            
                        }
                    }
                }
            }
            else
            {
                print_debug("TODO #if $_\n");
            }
            push @arrayMacro, $currentMacro;
        }

    }  #end of while
    if ($macroLevel != 0)
    {
        print "REPORT FATAL ERROR: macroLevel = $macroLevel \n";
    }
    close DEFINFILE;
}

sub print_debug {
	if( $debug eq 1 ){
		print @_;
	}
}

sub use_options {

    my $tempdir = undef;
    GetOptions (
	'dir=s'        => \$finddir,           # --dir ./src
	'debug!'       => \$debug,           # --debug
	'help!'        => \$help,            # --help
    );

    if( $help eq 1 )
    {
        print "checkMACRO.pl usage:\n";
        print "    --dir directory    //-dir /home/src/\n";
        print "    --debug            //print debug info\n";
        print "    --help             //print checkMACRO.pl usage\n";
    }

}
sub main_sub
{
    # get finddir from option, default set to current directory
    use_options();
    print "Searching *.c *.h *.cpp *.hpp *.cc files in directory $finddir\n";
    @filelist = `find $finddir -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" -o -name "*.cc"`;
    foreach $file (@filelist)
    {
        print_debug("Checking $file");
        $curFile = $file;
        my $grepresult = `grep "#endif" $file`;  #files that contain endif will be checked
        if($grepresult)
        {
            print_debug("calling checkMacroInFile\n");
            checkMacroInFile($file);
        }
    }

}

print "Begin of checkMACRO.pl\n";
main_sub();
print "End of checkMACRO.pl\n";
