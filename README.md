# SIDedit v4.02+

This is a minimally patched version of LaLa's ancient SIDedit v4.02 from 2004. 

## changes

* Added "List all files" option so that binaries can be loaded without 
having to rename them to "*.prg" first.
* Added browsing support for Windows folder names containing non-ASCII 
characters.
* Patched so it works with Perl and module versions still available today.
* Got rid of the annoying perl2exe "trial version" popup.


## howto build

Obviously there is a prebuilt win32 executable (32-bit) in the main folder. 
But in case you want to build the same thing from src or run the perl script 
directly, below some notes how I went about it (this might also help me to 
remember next time I might have to touch this.. which I do not intend to do):

### install Perl 

I used about the oldest 32-bit Strawberry distribution that I could find (Perl 
5.8.9.3 from 2009-10-17) I was not keen to encounter unnecessary migration work
with the SIDedit script from 2004 - but if you feel lucky then use whatever
version you like.

When you try to run 'perl.exe SIDedit.pl' now, the error messages in the 
command prompt will tell you what modules still need to be installed.

### use Perl's "cpan" command to install missing modules

If you need an overview what different versions of a module are available
then https://metacpan.org/ is a good place to go to. Specific versions 
here can either be downloaded directly or you can use the "MetaCPAN Explorer"
link to find out under what URL the respective version's archive file can be 
downloaded, e.g. https://cpan.metacpan.org/authors/id/L/LA/LALA/Audio-SID-3.03.tgz

Using Perl's "cpan" commandline tool, modules can either be downloaded in their
most recent version, e.g.:

`cpan> install Audio::SID`

or in a specific version:

`cpan> install LALA/Audio-SID-3.03.tgz`

Notice that you may first need to tell cpan on what servers to search, e.g.

`cpan> o conf urllist push https://cpan.metacpan.org`


The only module with a specific version requirement is probably Audio::SID 3.03
from the above example. I then also used an old Tk module (804.029_502) - again
to minimize the amount of changes to the version that LaLa might have used in
2004.

PS: to check which module version (e.g. of Tk) is used type: `cpan -D Tk` in a 
windows command prompt.

### patch 3rd party module

One of the extra modules that you'll have installed will be Tk::WaitBox. It 
must be patched by commenting out the line #58:
`#    $cw->transient($cw->toplevel)` (see C:\strawberry\perl\site\lib\Tk\WaitBox.pm) 

Once this has been done SIDedit.pl should run fine when you start it directly in
the Perl interpreter.

PS: if you intend to run the script directly you should copy the SIDedit.txt and
SIDedit.ini configuration files into the folder with the script.

### build windows exe

To create an .exe with all the Perl stuff in it, install the "PAR Packager":

`cpan> get pp`

`cpan> install pp`

you can then type the below in a windows command prompt:

`pp.bat --gui --compress=9 -u -o SIDedit.exe SIDedit.pl`

PS: make sure to copy the SIDedit.txt and SIDedit.ini configuration files into the 
folder with the exe file.



## license

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.




