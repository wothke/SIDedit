eval 'exec perl -w -S $0 ${1+"$@"}'
                if 0;

# SIDedit - a SID ripper's tool
#
# A Perl/Tk GUI app to read and edit SID files
# Copyright (C) 1999, 2004 LaLa <LaLa@C64.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#
# Tiny'R'Sid's patched version 4.02+
#
# This is basically the 4.02 version available on LaLa's webpage, EXCEPT
# for the below changes (which are marked with "XXX" comments).
#
# Added fixes to make it run with "today's" perl/module versions (I've been using:
# Perl v5.8.9 Strawberry on Windows10, SREZIC/Tk-804.029_502.tar.gz, 
# BPOWERS/Tk-WaitBox-1.3.tar.gz): 
#
# 1) the original logic of getting default background colors for enabled/disabled  
#    fields by querying the window no longer works - I just hardcoded them now.
#
# 2) The Tk::WaitBox module must be patched by commenting out the line #58:
#    $cw->transient($cw->toplevel). (see C:\strawberry\perl\site\lib\Tk\WaitBox.pm) 
#
# Functional changes are:
#
# 1) Added "List all files" option so that binaries can be loaded without 
#    having to rename them to "*.prg" first.
#
# 2) Added browsing support for Windows folder names containing non-ASCII characters.
#
BEGIN {
    if ($^O =~ /win32/i) {

        # Need to use these here to get around compile-time errors.
        require Win32; import Win32;
        require Win32API::File; import Win32API::File qw(:ALL);
        require Win32::API; import Win32::API;

        # Fork substitute.
        require Win32::Process; import Win32::Process;

        # Standard Tk copy-to-clipboard operation crashes under Win,
        # so use this instead.
        require Win32::Clipboard; import Win32::Clipboard;
		
		use utf8;	# XXX
		use Encode 'encode';
		binmode STDOUT, ":encoding(cp850)";
    }

    use Tk;
    use Tk::Balloon;
    use Tk::Checkbutton;
    use Tk::Dialog;
    use Tk::DialogBox;
    use Tk::LabFrame;
    use Tk::Optionmenu;
    use Tk::Radiobutton;
    use Tk::ROText;
    use Tk::BrowseEntry;
    use Tk::Scrollbar;
    use Tk::Button;
    use Tk::Entry;
    use Tk::Photo;
    use Tk::ToolBar;
    use Tk::NoteBook;
    use Tk::WaitBox;
    use Tk::DirTree;

    # The entry box for the directory shortcuts (PathEntry) can clear out its
    # contents when Tab is pressed, thus not used.
    # (Bug in Perl/Tk)
    #
    # use Tk::PathEntry;

    # Perl2EXE goes crazy when the POD viewer is used. Omitted.
    #
    # use Tk::Pod::Text;

    # Neat idea, but the tags need tweaking as the defaults look ugly.
    #
    # use Tk::ROTextANSIColor;

    use Audio::SID 3.03;
    use File::Basename;
    use File::Copy;
    use Cwd;
    use strict;
}

##############################################################################
#
# GLOBAL VARIABLES
#
##############################################################################

my $VERSION = "4.02+";

# External files used.
my $SIDEDIT_INI = 'SIDedit.ini';
my $SID_FORMAT  = 'SID_file_format.txt';
# my $SIDEDIT_POD  = 'SIDedit.pod';
# my $SIDEDIT_POD  = 'SIDedit.ansi';
my $SIDEDIT_POD  = 'SIDedit.txt';

# Stuff for SID object.
my $mySID = new Audio::SID();
my (@SIDfields) = $mySID->getFieldNames();

# These are predefined for convenience.
my (@topPack) = (-side => 'top', -anchor => 'center');
my (@bottomPack) = (-side => 'bottom', -anchor => 'center');
my (@rightPack) = (-side => 'right', -anchor => 'center');
my (@leftPack) = (-side => 'left', -anchor => 'center');
my (@xFill) = (-fill => 'x');
my (@yFill) = (-fill => 'y');
my (@bothFill) = (-fill => 'both');
my (@expand) = (-expand => 1);
my (@raised) = (-relief => 'raised');
my (@sunken) = (-relief => 'sunken');
my (@flat)   = (-relief => 'flat');
my (@noBorder) = (-padx => 0, -pady => 0);

%background = ();

# Windows specific stuff.

my $isWindows = 0;
$isWindows = 1 if ($^O =~ /win32/i);

if ($isWindows) {
    # Stupid Windows.
    push (@noBorder, -borderwidth => 0);
}

my $drive if ($isWindows);
my $directory = cwd;
my $separator = '/';

if ($isWindows) {
    $separator = '\\';
    GetDriveAndDir();
}

# Defining the types of the various fields.
my (@hexFields) = qw(dataOffset flags reserved);
my (@longhexFields) = qw(speed);
my (@c64hexFields) = qw(loadAddress initAddress playAddress);
my (@shorthexFields) = qw(startPage pageLength);
my (@decFields) = qw (songs startSong);
my (@v2Fields) = qw(flags startPage pageLength reserved);
my (@textFields) = qw (name author released);

# Changing these fields impacts the MD5 fingerprint.
my (@MD5Fields) = qw(loadAddress initAddress playAddress songs speed);

# Recognized file extensions.
my (@datfiles) = qw(dat prg p00 c64 psid);
my (@inffiles) = qw(sid inf info);
my (@sidfiles) = qw(sid);

# Settings.
my $ConfirmDelete = 1;
my $ConfirmSave = 1;
my $CopyHow = 'selected';
my $ListSIDFiles = 1;
my $ListDataFiles = 0;
my $ListInfoFiles = 0;
my $ListAllFiles = 0;	#XXX
my $SaveV2Only = 1;
my $ShowAllFields = 1;
my $SIDPlayer = '';
my $SIDPlayerOptions = '';
my $HexEditor = '';
my $HexEditorOptions = '';
my $SaveSettingsOnExit = 1;
my $DisplayDataAs = 'hex';
my $DisplayDataFrom = 'loadAddress';
my $SaveDataAs = 'binary';
my $PasteSelectedOnly = 1;
my @ToolList;
my $ToolListMaxLength = 10;
my $ToolOutput;
my $lastSaveDir;
my $ShowTextBoxGeometry;
my $MainWindowGeometry;
my $ShowSIDDataGeometry;
my $AlwaysGoToSaveDir = 1;
my $DefaultDirectory = $directory;
my $SaveDirectory = $directory;
my $HVSCDirectory = $directory;
my $ShowColors = 1;
my $AutoHVSCFilename = 0;

if ($isWindows) {
    $DefaultDirectory = $drive . $directory;
    $SaveDirectory = $drive . $directory;
    $HVSCDirectory = $drive . $directory;
}


# Defines what fields can be copied/pasted. Defaults provided below.
my %copy;

$copy{'filename'} = 0;
$copy{'filesize'} = 0;
$copy{'MD5'} = 0;
foreach (@SIDfields) {
    $copy{$_} = 0;
}
$copy{'author'} = 1;
$copy{'released'} = 1;

# Initial values.
my $modified = 0;           # This is 1 if any SID field was modified.
my $filename = '<NONE>';    # Just so that we display something initially.
my $filesize = 0x7C;
my $realLoadAddress = 0;
my $loadRangeEnd = 0;
my $loadRange = '$0000 - $0000';
my $SIDMD5 = '<NONE>';
my $MUSPlayer = 0;
my $PlaySID = 0;
my $C64BASIC = 0;
my $Video = 0;
my $SIDChip = 0;
my $modifyBytes = '00 00';
my $JumpToMark = '1.0';

# Constants for individual bitfields inside 'flags'.
my $MUSPLAYER_OFFSET = 0; # Bit 0.
my $PLAYSID_OFFSET   = 1; # Bit 1. (PSID v2NG only)
my $C64BASIC_OFFSET  = 1; # Bit 1. (RSID only)
my $VIDEO_OFFSET     = 2; # Bits 2-3.
my $SIDCHIP_OFFSET   = 4; # Bits 4-5.

my $STATUS = "SIDedit v$VERSION - (C) 1999-2004 by LaLa <LaLa\@C64.org>";
my $showAllButtonText = "Show credits only";

# Contains the values of all SID fields (needed for the Entry widgets).
my %SIDfield;

# This event ID is for keeping track of time between keypresses in the
# dir and file listboxes.
my $keypressEventID;

# It's 1 if $KEYPRESS_DELAY hasn't elapsed, yet.
my $keypressOn = 0;

my $KEYPRESS_DELAY = 500; # In millisec.
my $keypresses = ''; # Holds subsequent keypresses.

# Allow global access to these widgets.
my $window;
my $drivelistbox if ($isWindows);
my $dirlistbox;
my $drivelistbox_called = 0; # To prevent drivelistbox from calling itself infinitely.
my $filelistbox;
my $direntry;
my $SIDframe;
my $filenameentry;
my $statusbar;
my $tooltip;
my $magicIDButtonPSID;
my $magicIDButtonRSID;
my $version1Button;
my $version2Button;
my $loadAddressEntry;
my $initAddressEntry;
my $playAddressEntry;
my $speedEntry;
my $speedEditButton;
my $PlaySIDButtonState = 'normal';
my $C64BASICButtonState = 'normal';
my $dataOffsetEntry;
my $flagsEntry;
my $flagsEditButton;
my $startPageEntry;
my $pageLengthEntry;
my $reservedEntry;
my $fileNavPopupMenu;

# We find these out at run-time.
my $DISABLED_ENTRY_COLOR;
my $ENABLED_ENTRY_COLOR;

# XXX the original init on demand logic seems to be broken - probably older
# versions accepted the "undefined" values .. but this is no longer the case
$DISABLED_ENTRY_COLOR = '#E0E0E0';
$ENABLED_ENTRY_COLOR = '#FFFFFF';

my $MINWIDTH; # Minimum width and height for window to prevent "jumping" effect.
my $MINHEIGHT;

# Icons.

my $SIDeditIconString = <<EOF;
/* XPM */
static char * unknown[] = {
/* width height ncolors chars_per_pixel */
"32 32 3 1",
/* colors */
". s None c None", /* transparent */
"- c #ffff00",
"X c #c0c000",
/* pixels */
"................................",
".......XXXXXX.XXXXXXXXXXX.......",
"......XX----XXX--X------XX......",
".....XX------XX--X-------XX.....",
".....X---XX---X--X--XXX---X.....",
".....X--XXXX--X--X--X.XX--X.....",
".....X--XX.XXXX--X--X..X--X.....",
".....X---XXXX.X--X--X..X--X.....",
".....XX-----XXX--X--X..X--X.....",
"......XX-----XX--X--X..X--X.....",
".......XXXX---X--X--X..X--X.....",
".....XXXX.XX--X--X--X..X--X.....",
".....X--XXXX--X--X--X.XX--X.....",
".....X---XX---X--X--XXX---X.....",
".....XX------XX--X-------XX.....",
"......XX----XXX--X------XX......",
".......XXXXXX.XXXXXXXXXXX.......",
"................................",
"....XXXXXXXXXXXXXXXXXXXXXXXXX...",
"....X------X-----XX--X------X...",
"....X------X------X--X------X...",
"....X--XXXXX--XX--X--XXX--XXX...",
"....X--XXX.X--XX--X--X.X--X.....",
"....X----X.X--XX--X--X.X--X.....",
"....X----X.X--XX--X--X.X--X.....",
"....X--XXX.X--XX--X--X.X--X.....",
"....X--XXXXX--XX--X--X.X--X.....",
"....X------X------X--X.X--X.....",
"....X------X-----XX--X.X--X.....",
"....XXXXXXXXXXXXXXXXXX.XXXX.....",
"................................",
"................................"
};
EOF

my $HVSCIconString = <<EOF;
/* XPM */
static char * unknown[] = {
/* width height ncolors chars_per_pixel */
"16 16 3 1",
/* colors */
". s None c None", /* transparent */
"X c #0000ff",
"- c #8080e0",
/* pixels */
"................",
"..XX..XX.XX..XX.",
"..XX-.XX-XX-.XX-",
"..XXXXXX-XX-.XX-",
"..XXXXXX-XX-.XX-",
"..XX--XX-.XXXX--",
"..XX-.XX-..XX--.",
"...--..--...--..",
"................",
"...XXXXX..XXXXX.",
"..XX-----XX-----",
"..XXXXX..XX-....",
"...XXXXX-XX-....",
"....--XX-XX-....",
"..XXXXX-..XXXXX.",
"...----....-----",
};
EOF

# ToolBar icons lifted from Tk::ToolBar -> tkIcons.
my (@toolbaricons) = (
'actcross16:act act16 16:photo:16 16:R0lGODlhEAAQAIIAAASC/PwCBMQCBEQCBIQCBAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAMuCLrc/hCGFyYLQjQsquLDQ2ScEEJjZkYfyQKlJa2j7AQnMM7NfucLze1FLD78CQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'acthelp16:act act16 16:photo:16 16:R0lGODlhEAAQAIMAAPwCBAQ6XAQCBCyCvARSjAQ+ZGSm1ARCbEyWzESOxIy63ARalAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAQ/EEgQqhUz00GEJx2WFUY3BZw5HYh4cu6mSkEy06B72LHkiYFST0NRLIaa4I0oQyZhTKInSq2eAlaaMAuYEv0RACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYgUHJvIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJpZ2h0cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=',
'actreload16:act act16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBCRaJBxWJBxOHBRGBCxeLLTatCSKFCymJBQ6BAwmBNzu3AQCBAQOBCRSJKzWrGy+ZDy+NBxSHFSmTBxWHLTWtCyaHCSSFCx6PETKNBQ+FBwaHCRKJMTixLy6vExOTKyqrFxaXDQyNDw+PBQSFHx6fCwuLJyenDQ2NISChLSytJSSlFxeXAwODCQmJBweHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAaBQIBQGBAMBALCcCksGA4IQkJBUDIDC6gVwGhshY5HlMn9DiCRL1MyYE8iiapaSKlALBdMRiPckDkdeXt9HgxkGhWDXB4fH4ZMGnxcICEiI45kQiQkDCUmJZskmUIiJyiPQgyoQwwpH35LqqgMKiEjq5obqh8rLCMtowAkLqovuH5BACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYgUHJvIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJpZ2h0cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=',
'actrun16:act act16 16:photo:16 16:R0lGODlhEAAQAIMAAPwCBAQCBPz+/ISChKSipMTCxLS2tLy+vMzOzMTGxNTS1AAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAARlEMgJQqDYyiDGrR8oWJxnCcQXDMU4GEYqFN4UEHB+FEhtv7EBIYEohkjBkwJBqggEMB+ncHhaBsDUZmbAXq67EecQ02x2CMWzkAs504gCO3qcDZjkl11FMJVIN0cqHSpuGYYSfhEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'apppencil16:app app16 16:photo:16 16:R0lGODlhEAAQAIMAAASC/IQCBMQCBPzCxAQCBPz+/MTCxISChDQyNKSipEQCBAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAARDEMhJZRBD1H2z3lMnjKCFjUJQimOgcmcbELCXzjXq0hV785WCQYcDFQjDXeloMByKG6YTAdwIDAlqSZJSVFeKLcUfAQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'apptool16:app app16 16:photo:16 16:R0lGODlhEAAQAIMAAPwCBAQCBISChGRmZMTCxKSipLS2tHx6fPz+/OTm5FxaXOzu7DQyNMzOzAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAReEMhAq7wYBDECKVSGBcbRfcEYauSZXgFCrEEXgDCSeIEyzKSXZoBYVCoJVIqBGByKu0Cy8QHxmgNngWCkGgqsGWFseu6oMApoXHAWhWnKrv0UqeYDe0YO10/6fhJ+EQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'devfloppymount16:dev dev16 16:photo:16 16:R0lGODlhEAAQAIQAAPwCBAQCBMTCxARmZPz+/FSWlLSytKSipERCRIyOjISChOTm5HRydNza3GRiZFRSVASCBARCBDTSJIT+bAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAVrICCOQBCQKBkIw5mqLFG47zoQ+FwbN57TosDhgPD5dMEEIqE04kwlBWKBUEiNVYFpyqAyGEUCgqEtERiNNMLhQKzLQYJg7n7Y4aMAwbCUPvAQeWNgfzQQETAIhSMQEogwgBITQEGGEREmfiEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'devfloppyunmount16:dev dev16 16:photo:16 16:R0lGODlhEAAQAIMAAPwCBAQCBMTCxARmZPz+/FSWlLSytKSipERCRIyOjISChOTm5HRydNza3GRiZFRSVCH5BAEAAAAALAAAAAAQABAAAARcEMgJQqCYBjFu1hxReN82EOhYGieaklJwHIjrqnGCJLqNWhUFYoFQCG1FgWXIIDIYNQKCoawQGI0swuFAbKsxgmDsfZjBkwDBsNM90Jot9A3DbBD0Dwiur9QnfhEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'devscreen16:dev dev16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBFxaXFRSVPz+/PT29OTm5OTi5DQyNDw+PERGRExKTHx+fISChIyKjHRydFxeXDQ2NCQmJBQSFAQCBERCRMTGxHR2dGRiZExOTDw6PCQiJAwODCwuLFRWVOzu7BweHAwKDCwqLHx6fBQWFGxqbGRmZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAanQIBwSCwKAwKkMslEAgSDqDRKqBYKhkNgcDggEorkMrDQchkNhuOhgEQkk0l5S2lUGpYLJqPZTAwMHB0DCmhqAW0Rfh5zAxgOkBcCFAcfIBMECxwBBAEPFw8dChkhcBMDDAcdnQqtFKSWcQMimx4dGRkQBxGxsg6bBQEawx8jl3GnJFoFHRNXVVNRJYIFDAsL1tgiDiQXFx0HABwcXeQH5OjkRutEfkEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'devspeaker16:dev dev16 16:photo:16 16:R0lGODlhEAAQAIMAAPwCBFxaXAT+/DQyNATCxMTCxPz+/AQCBKSipASChAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAARWEMgJQqCXziDG2JoUEENhZBkmHIWJVptAmqcIW/Js1MiF56TBzkckAAcHoa9nMRKeA4TyJk0knsHhTeK5khBaH2VwLYVh40TJhQ6RzeIQV32Quz8hfwQAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'edit16:edit edit16 16:photo:16 16:R0lGODlhEAAQAIYAAPwCBFxaVMR+RPzKjNze3AQCBMR6RPzGjPyODPz+/MzOzPyKDPyKBPz29OTWzPyGDPyGBOx6BOza1OR2BKROBNSOXKRKBBwOBOzu7PTWxPzizOySZPyCDFxaXOy2lNRyRMxmJCQOBPTm1OzStPTKrMR+XIRWLFxGNCQSBDQyNIRSNDQuJERGRLyqlNzSvIx6ZKRuVEw6LLSyrLymhKSShBwaFFROTJyWjMS+vNzW1OTazNzKrHRqXOzezOTOpPTq3OzWvOTStLyedMS+rLy2pMSynMSulAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAewgAAAAYSFhoQCA4IBBI2OjgUGBwiLBAmXlpcKkgsMlZcJBA0JDpIPEBGVjwkSBgOnExSfmBIVBxAMExYXswkYGRobHLq8gh2PHhoeHyAWIYKzIiMkJSYnKCnQg5YNHtQqKywtK9qMBC4vMDEBMjIz2dCMDTQ1Njc4OToz5PEEOzw3ZPToMcLHO23HfogQ0QMIkCA+hPBbhAPHECJFjMyYIUQIvEUpUqwQOXKkSEF+AgEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'editcopy16:edit edit16 16:photo:16 16:R0lGODlhEAAQAIUAAFxaXPwCBNze3GxubERCRPz+/Pz29Pzy5OTe3LS2tAQCBPTq3PTizLyulKyqrOzexLymhLy+vPTy9OzWvLyifMTCxHRydOzSrLyihPz6/OTKpLyabOzu7OTm5MS2nMSqjKSipDQyNJyenLSytOTi5NTS1JyanNTW1JSWlLy6vKyurAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAQABAAAAaUQIBwCAgYj0eAYLkcEJBIZWFaGBie0ICUOnBiowKq4YBIKIbJcGG8YDQUDoHTKGU/HhBFpHrVIiQHbQ8TFAoVBRZeSoEIgxcYhhkSAmZKghcXGht6EhwdDmcRHh4NHxgbmwkcCwIgZwqwsbAhCR0CCiIKWQAOCQkjJAolJrpQShK2wicoxVEJKSMqDiAizLuysiF+QQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'editpaste16:edit edit16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBCQiFHRqNIx+LFxSBDw6PKSaRPz+/NTOjKyiZDw+POTe3AQCBIR2HPT23Ly2dIR2FMTCxLS2tCQmJKSipExGLHx+fHR2dJyenJyanJSSlERCRGRmZNTW1ERGRNze3GxubBweHMzOzJSWlIyOjHRydPz29MzKzIyKjPTq3Ly2rLy+vISGhPzy5LymhISChPTizOzWvKyurPTexOzSrDQyNHx6fCwuLGxqbOzKpMSabAQGBMS2nLyulMSidAAAACH5BAEAAAAALAAAAAAQABAAAAa7QIBQGBAMCMMkoMAsGA6IBKFZECoWDEbDgXgYIIRIRDJZMigUMKHCrlgul7KCgcloNJu8fsMpFzoZgRoeHx0fHwsgGyEACiIjIxokhAeVByUmG0snkpIbC5YHF4obBREkJCgon5YmKQsqDAUrqiwsrAcmLSkpLrISLC/CrCYOKTAxvgUywhYvGx+6xzM0vjUSNhdvn7zIMdUMNxw4IByKH8fINDk6DABZWTsbYzw9Li4+7UoAHvD+4X6CAAAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'edittrash16:edit edit16 16:photo:16 16:R0lGODlhEAAQAIIAAPwCBAQCBKSipFxaXPz+/MTCxISChDQyNCH5BAEAAAAALAAAAAAQABAAAANQCKrRsZA5EYZ7K5BdugkdlQVCsRHdoGLMRwqw8UWvIKvGwTICQdmGgY7W+92GEJKPdNwBlMYgMlNkSp3QgOxKXAKFWE0UHHlObI3yyFH2JwAAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'filenew16:file file16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBFxaXNze3Ly2rJyanPz+/Ozq7GxqbPz6/GxubNTKxDQyNIyKhHRydERCROTi3PT29Pz29Pzy7PTq3My2pPzu5PTi1NS+rPTq5PTezMyynPTm1Pz69OzWvMyqjPTu5PTm3OzOtOzGrMSehNTCtNS+tAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAZ/QAAgQCwWhUhhQMBkDgKEQFIpKFgLhgMiOl1eC4iEYrtIer+MxsFRRgYe3wLkMWC0qXE5/T6sfiMSExR8Z1YRFRMWF4RwYIcYFhkahH6AGBuRk2YCCBwSFZgdHR6UgB8gkR0hpJsSGCAZoiEiI4QKtyQlFBQeHrVmC8HCw21+QQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'filefind16:file file16 16:photo:16 16:R0lGODlhEAAQAIYAAPwCBCQmJDw+PBQSFAQCBMza3NTm5MTW1HyChOT29Ozq7MTq7Kze5Kzm7Oz6/NTy9Iza5GzGzKzS1Nzy9Nz29Kzq9HTGzHTK1Lza3AwKDLzu9JTi7HTW5GTCzITO1Mzq7Hza5FTK1ESyvHzKzKzW3DQyNDyqtDw6PIzW5HzGzAT+/Dw+RKyurNTOzMTGxMS+tJSGdATCxHRydLSqpLymnLSijBweHERCRNze3Pz69PTy9Oze1OTSxOTGrMSqlLy+vPTu5OzSvMymjNTGvNS+tMy2pMyunMSefAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAe4gACCAAECA4OIiAIEBQYHBAKJgwIICQoLDA0IkZIECQ4PCxARCwSSAxITFA8VEBYXGBmJAQYLGhUbHB0eH7KIGRIMEBAgISIjJKaIJQQLFxERIialkieUGigpKRoIBCqJKyyLBwvJAioEyoICLS4v6QQwMQQyLuqLli8zNDU2BCf1lN3AkUPHDh49fAQAAEnGD1MCCALZEaSHkIUMBQS8wWMIkSJGhBzBmFEGgRsBUqpMiSgdAD+BAAAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7',
'foldernew16:folder folder16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBAQCBPz+hPz+BOSmZPzSnPzChFxaXMTCBPyuZPz+xPzGhEwyHExOTPz+/MSGTFROTPT29OTm5KyurDQyNNza3Ozq5Nze3LR+RLy+vJyenMzKzNTS1Ly6vJSWlFRSTMzOzMTGxLS2tKSmpGxubBQSFAwKDKSinJyanIyOjCQiJERCRERGRBweHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAaNQIBwSCwaj8ikcokMCIqBaEDoBAQG1meAUDAQpIcBQoy1dg2JdBqhECgQ1IWB0WgcBIOBwIHXBwwPEBEREhIBbG4IExR/DBUVFhIXV2NjDVYYDY8SFU4ZVxpVAQwbGxynGxkdTh6XVh8gGSGzGSITIxokJUImGSMTwLcnKCkprgAqDSt1zCssKxQtQ35BACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYgUHJvIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJpZ2h0cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=',
'folderopen16:folder folder16 16:photo:16 16:R0lGODlhEAAQAIYAAPwCBAQCBExKTBQWFOzi1Ozq7ERCRCwqLPz+/PT29Ozu7OTm5FRSVHRydIR+fISCfMTCvAQ6XARqnJSKfIx6XPz6/MzKxJTa9Mzq9JzO5PTy7OzizJSOhIyCdOTi5Dy65FTC7HS2zMzm7OTSvNTCnIRyVNza3Dw+PASq5BSGrFyqzMyyjMzOzAR+zBRejBxqnBx+rHRmTPTy9IyqvDRylFxaXNze3DRujAQ2VLSyrDQ2NNTW1NTS1AQ6VJyenGxqbMTGxLy6vGRiZKyurKyqrKSmpDw6PDw6NAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAfCgACCAAECg4eIAAMEBQYCB4mHAQgJCgsLDAEGDQGIkw4PBQkJBYwQnRESEREIoRMUE6IVChYGERcYGaoRGhsbHBQdHgu2HyAhGSK6qxsjJCUmJwARKCkpKsjKqislLNIRLS4vLykw2MkRMRAGhDIJMzTiLzDXETUQ0gAGCgU2HjM35N3AkYMdAB0EbCjcwcPCDBguevjIR0jHDwgWLACBECRIBB8GJekQMiRIjhxEIlBMFOBADR9FIhiJ5OnAEQB+AgEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
'navhome16:nav nav16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBDw6PBQWFCQiJAQCBFxeXMTCxJyanDwyLDQqLFRSVLSytJSSlISChCQmJERGRFRWVGxubKSmpJyenGRmZLy+vOzq7OTi5Ly6vGRiZPTy9Pz6/OTm5ExOTPT29BwaHNza3NS6tJRqRGQqBNy6pIyKjDwGBPTe1JSWlDQyNOTGrNRiBGwmBIRaLNymdLxWBHxGFNySXCwqLKyqrNR6LKxGBNTS1NTW1Jw+BEweDDQ2NAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAaoQIBwCAgIiEjAgAAoGA6I5DBBUBgWjIZDqnwYGgVIoTGQQgyRiGRCgZCR1nTFcsFkHm9hBp2paDYbHAsZHW9eERkYGh4eGx4ag3gfSgMTIBshIiMkGyAlCCZTEpciJyQjGxcoKUQBEhcbIiorLB4XEltDrhcaLS4vtbcJra8bMDHAGrcyrTMXHjA0NSypEsO6EzY3IzU4OdoTzK0BCAkDMgkIOjJlAH5BACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYgUHJvIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJpZ2h0cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=',
'navup16:nav nav16 16:photo:16 16:R0lGODlhEAAQAIUAAPwCBBRObAwSHBRSdISevBRWfAweLNzu/BSOrAQWLPz6/FzC3DzW5BxObHTS5ByyzAyixEze7BSStBRWdAyWvByixAQSHCQ2TAQCBBRGZJze7CS61BSavAxefMzq9ETW3CSWtAwmPPz+/CzG1ITC3FyuxBSCnAQeLAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAZfQIBwSCwaj8hhQJAkDggFQxMQIBwQhUSyqlgwsFpjg6BwPCARySSstC4eFAqEURlYhoMLBpPRUDYcHXt7RgUeFB8gIU0BIoiKjAcUIwiLSQUkJRsmGIwJJwmEU6OkfkEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==',
);

##############################################################################
#
# SUBROUTINES
#
##############################################################################


##############################################################################
#
# SID field checking
#
##############################################################################

# First param: value to recalculate, second param (optional): how many digits
# to take into account. If second param is 0, hex value will be calculated over
# all digits.
sub HexValue {
    my ($value, $digits) = @_;

    # Remove leading 0x.
    $value =~ s/^0x//;
    # Remove non-digits.
    $value =~ s/[^0-9a-f]//ig;

    if ($digits) {
        $value = substr($value,0,$digits);
    }

    $value = hex("0x0" . $value);
    return ($value);
}

sub CheckMagicID {
    my $address = HexValue($SIDfield{'loadAddress'},4);

    if ($SIDfield{'magicID'} eq 'RSID') {

        if ($address != 0) {
            # Replace first two bytes with the actual load address.
            $SIDfield{'data'} = pack('C', $address & 0xFF) . pack('C', ($address >> 8) & 0xFF) . $SIDfield{'data'};
        }
        $SIDfield{'version'} = 2;
        $SIDfield{'loadAddress'} = '$0000';
        $SIDfield{'playAddress'} = '$0000';
        $SIDfield{'speed'} = "0x00000000";
    }
    UpdateMagicIDFields();
    UpdateFlags();
    UpdateLoadAddress();
    RecalcMD5();
}

sub CheckVersion {
    if ($SIDfield{'version'} <= 1) {
        $SIDfield{'magicID'} = 'PSID';
        $SIDfield{'version'} = 1;
        $SIDfield{'dataOffset'} = "0x0076";
        $SIDfield{'flags'} = "0x0000";
        $SIDfield{'startPage'} = '$00';
        $SIDfield{'pageLength'} = '$00';
        $SIDfield{'reserved'} = "0x0000";
    }
    elsif ($SIDfield{'version'} >= 2) {
        $SIDfield{'version'} = 2;
        if (HexValue($SIDfield{'dataOffset'}) < 0x7C) {
            $SIDfield{'dataOffset'} = "0x007C";
        }
    }
    UpdateSize();
    UpdateV2Fields();
    UpdateMagicIDFields();
    UpdateFlags();
    RecalcMD5();
}

sub CheckDataOffset {
    if ($SIDfield{'version'} == 1) {
        $SIDfield{'dataOffset'} = "0x0076";
    }
    elsif ($SIDfield{'version'} == 2) {
        if (HexValue($SIDfield{'dataOffset'}) < 0x7C) {
            $SIDfield{'dataOffset'} = "0x007C";
        }
    }
    $SIDfield{'dataOffset'} = sprintf("0x%04X", HexValue($SIDfield{'dataOffset'}, 4));
    UpdateSize();
}

sub UpdateSize {
    $filesize = HexValue($SIDfield{'dataOffset'}) + length($SIDfield{'data'});
}

sub CheckSongs {
    $SIDfield{'songs'} =~ s/\D//g;
    $SIDfield{'songs'} =~ s/^0+//;
    if (!$SIDfield{'songs'} or $SIDfield{'songs'} <= 1) {
        $SIDfield{'songs'} = 1;
    }
    elsif ($SIDfield{'songs'} > 256) {
        $SIDfield{'songs'} = 256;
    }
}

sub CheckStartSong {
    $SIDfield{'startSong'} =~ s/\D//g;
    $SIDfield{'startSong'} =~ s/^0+//;
    if (!$SIDfield{'startSong'} or $SIDfield{'startSong'} <= 1) {
        $SIDfield{'startSong'} = 1;
    }
    elsif ($SIDfield{'startSong'} > $SIDfield{'songs'}) {
        $SIDfield{'startSong'} = $SIDfield{'songs'};
    }
}

# Check length of textual field.
sub CheckTextLength($) {
    my ($field) = @_;

    if (length($SIDfield{$field}) > 31) {
        $SIDfield{$field} = substr($SIDfield{$field},0,31);
    }
}

sub CheckRelocInfo {
    my $startPage = HexValue($SIDfield{'startPage'},2);
    my $pageLength = HexValue($SIDfield{'pageLength'},2);

    if (($startPage == 0) or ($startPage == 0xFF)) {
        $SIDfield{'pageLength'} = '$00';
    }
    elsif ((($startPage << 8) + ($pageLength << 8) - 1) > 0xFFFF) {
        $SIDfield{'pageLength'} = sprintf('$%02X', 0xFF - $startPage);
    }
    elsif ($pageLength == 0) {
        $SIDfield{'pageLength'} = '$01';
    }

    $SIDfield{'startPage'} = sprintf('$%02X', HexValue($SIDfield{'startPage'}, 2));
    $SIDfield{'pageLength'} = sprintf('$%02X', HexValue($SIDfield{'pageLength'}, 2));
}

sub UpdateLoadAddress {
    $mySID->set('loadAddress', HexValue($SIDfield{'loadAddress'}, 4));

    RecalcMD5();

    $realLoadAddress = $mySID->getRealLoadAddress();
    $loadRangeEnd = $realLoadAddress + length($SIDfield{'data'}) - 1;

    if ($loadRangeEnd < 2) {
        $loadRangeEnd = 0;
    }
    elsif ($SIDfield{'loadAddress'} == 0) {
        $loadRangeEnd -= 2;
    }

    $loadRange = sprintf('$%04X - $%04X', $realLoadAddress, $loadRangeEnd);
}

sub UpdateFlags {
    $SIDfield{'flags'} = HexValue($SIDfield{'flags'}, 4);

    if ($SIDfield{'magicID'} eq 'PSID') {
        $PlaySID  = ($SIDfield{'flags'} >> $PLAYSID_OFFSET) & 0x1;
    }
    else {
        $C64BASIC = ($SIDfield{'flags'} >> $C64BASIC_OFFSET) & 0x1;
    }

    $MUSPlayer = ($SIDfield{'flags'} >> $MUSPLAYER_OFFSET) & 0x1;
    $Video     = ($SIDfield{'flags'} >> $VIDEO_OFFSET) & 0x3;
    $SIDChip   = ($SIDfield{'flags'} >> $SIDCHIP_OFFSET) & 0x3;

    $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});

    if ($SIDfield{'magicID'} eq 'RSID') {
        if ($C64BASIC) {
            $SIDfield{'initAddress'} = '$0000';
            $initAddressEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        }
        else {
            $initAddressEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        }
    }
}

# Makes filename HVSC compliant. (Modeled after Shark's SID2LFN.)
sub HVSCLongFilename {
    my $tempfilename;

    # DRAX clause: if title is "Worktune" it is not renamed.
    if ($SIDfield{'name'} eq "Worktune") {
        $tempfilename = $filename;
        $tempfilename =~ s/\.sid$//i;
    }
    elsif (!$SIDfield{'name'} or $SIDfield{'name'} eq '<?>') {
        # No valid title. Try last name (or handle).

        if ($SIDfield{'author'} eq '<?>') {
            $tempfilename = "Unknown";
        }
        else {
            $tempfilename = $SIDfield{'author'};
            $tempfilename =~ s/^\s+//;
            if ($tempfilename =~ /^\S+\s+(\S+)(\s+.*)?$/) {
                $tempfilename = $1; # Select last name (hopefully).
            }
        }
    }
    else {
        $tempfilename = $SIDfield{'name'};
        $tempfilename =~ s/^the //i; # No "The " as the first word.
    }

    # Handle apostrophe (both types) for special cases.
    # For other cases it'll be replaced with an underscore.
    $tempfilename =~ s/[\x27\x60]([dlmrstv])/$1/g;
    $tempfilename =~ s/[\x27\x60]\s*(\S)\s*[\x27\x60]/_$1_/ig;

    # Spaces surrounding a dash are removed.
    $tempfilename =~ s/\s+-\s+/-/g;

    # Ampersand is made a word.
    $tempfilename =~ s/&/and/g;

    # Plus is made a word if ending or beginning a title,
    # or if it's between words.
    $tempfilename =~ s/\+\s*$/_plus/;
    $tempfilename =~ s/^\+\s*/Plus_/;
    $tempfilename =~ s/(\D)\s*\+\s*(\D)/$1_plus_$2/;

    # JCH "TIME: " clause.
    $tempfilename =~ s/\s+TIME:.*$//i;

    # Spec chars:
    $tempfilename =~ s/[ü]/ue/g;
    $tempfilename =~ s/[Ü]/Ue/g;
    $tempfilename =~ s/[øö]/oe/g;
    $tempfilename =~ s/[ØÖ]/Oe/g;
    $tempfilename =~ s/[ß]/ss/g;
    $tempfilename =~ s/[àáãâ]/a/g;
    $tempfilename =~ s/[ÀÁÃÂ]/A/g;
    $tempfilename =~ s/[å]/aa/g;
    $tempfilename =~ s/[Å]/Aa/g;
    $tempfilename =~ s/[ñ]/n/g;
    $tempfilename =~ s/[Ñ]/N/g;
    $tempfilename =~ s/[òôõó]/o/g;
    $tempfilename =~ s/[ÒÔÕÓ]/O/g;
    $tempfilename =~ s/[ûùú]/u/g;
    $tempfilename =~ s/[ÛÙÚ]/U/g;
    $tempfilename =~ s/[éèêë]/e/g;
    $tempfilename =~ s/[ÉÈÊË]/E/g;
    $tempfilename =~ s/[ïìîí]/i/g;
    $tempfilename =~ s/[ÏÌÎÍ]/I/g;
    $tempfilename =~ s/[ð]/d/g; # ???
    $tempfilename =~ s/[Ð]/D/g; # ???
    $tempfilename =~ s/[ý]/y/g; # ???
    $tempfilename =~ s/[Ý]/Y/g; # ???
    $tempfilename =~ s/[äæ]/ae/g;
    $tempfilename =~ s/[ÄÆ]/Ae/g;
    $tempfilename =~ s/[ç]/c/g;
    $tempfilename =~ s/[Ç]/C/g;

    $tempfilename =~ s/[^a-zA-Z0-9_-]/_/g; # Nothing else allowed other than these chars.

    # Take care of ugly cases.
    $tempfilename =~ s/__+/_/g; # Duplicates.
    $tempfilename =~ s/--+/-/g; # Duplicates.
    $tempfilename =~ s/_-/-/g;  # Ugly combination.
    $tempfilename =~ s/-_/-/g;  # Ugly combination.
    $tempfilename =~ s/^[_-]+//; # Can't begin filename with these.

    if ($PlaySID) {
        # Max 21 + "_PSID.sid" extension length for filenames.
        $tempfilename = substr($tempfilename, 0, 21);
    }
    else {
        # Max 26 + ".sid" extension length for filenames.
        $tempfilename = substr($tempfilename, 0, 26);
    }

    $tempfilename =~ s/[_-]+$//; # Can't end filename with these.

    if ($tempfilename ne '') {
        if ($PlaySID) {
            $tempfilename .= "_PSID";
        }

        $filename = $tempfilename . ".sid";
        $modified = 1;
        ErrorBox("The filename is now HVSC compliant.",
            "Filename is HVSC compliant") if (!$AutoHVSCFilename);
        $STATUS = "Filename is now HVSC compliant.";
    }
    else {
        # All the manipulations left nothing - leave original filename.

        ErrorBox("Couldn't create an HVSC compliant filename!\nPlease, make up a filename yourself.",
            "Error creating filename!");
        $STATUS = "Couldn't create HVSC compliant filename!";
    }
}

# Checks whether the value of all fields are valid. Returns TRUE if any was not valid.
sub FieldsNotValid {
    my @errorText = ();
    my $errorText;
    my $field;
    my $fieldsNotValid = 0;
    my $initAddress = HexValue($SIDfield{'initAddress'},4);
    my $playAddress = HexValue($SIDfield{'playAddress'},4);
    my $startPage = HexValue($SIDfield{'startPage'},2) << 8;
    my $pageLength = HexValue($SIDfield{'pageLength'},2) << 8;
    my $speed = HexValue($SIDfield{'speed'},8);
    my $initAddressProblem = 0;
    my $playAddressProblem = 0;
    my $speedProblem = 0;

    if (($filename eq '<NONE>') or ($filename =~ /^\s*$/)) {
        push (@errorText, "- invalid filename");
    }

    if (($SIDfield{'version'} != 1) and ($SIDfield{'version'} != 2)) {
        push (@errorText, "- version number '$SIDfield{version}' is invalid");
    }

    if ((($SIDfield{'version'} == 1) and (HexValue($SIDfield{'dataOffset'}) != 0x76)) or
        (($SIDfield{'version'} == 2) and (HexValue($SIDfield{'dataOffset'}) < 0x7C)) ) {
        push (@errorText, "- version number and dataOffset mismatch");
    }

    foreach $field (@hexFields, @c64hexFields) {
        next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
        if ((HexValue($SIDfield{$field}) < 0) or (HexValue($SIDfield{$field}) > 0xffff)) {
            push (@errorText, "- $field" . ' is out of range (valid range is $0000-$FFFF)');
        }
    }

    # It's a 4-byte hex field.
    foreach $field (@longhexFields) {
        next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
        if ((HexValue($SIDfield{$field}) < 0) or (HexValue($SIDfield{$field}) > 0xffffffff)) {
            push (@errorText, "- $field is out of range (valid range is 0-0xFFFFFFFF)");
        }
    }

    # It's a 1-byte hex field.
    foreach $field (@shorthexFields) {
        next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
        if ((HexValue($SIDfield{$field}) < 0) or (HexValue($SIDfield{$field}) > 0xff)) {
            push (@errorText, "- $field" . ' is out of range (valid range is $00-$FF)');
        }
    }

    foreach $field (qw(songs startSong)) {
        if (($SIDfield{$field} < 1) or ($SIDfield{$field} > 256)) {
            push (@errorText, "- $field is out of range (valid range is 1-256)");
        }
    }

    if ($SIDfield{'startSong'} > $SIDfield{'songs'}) {
        push (@errorText, "- startSong is greater than number of songs");
    }

    foreach $field (qw(name author released)) {
        # Strip trailing whitespace.
        $SIDfield{$field} =~ s/\s+$//;
        if (length($SIDfield{$field}) > 31) {
            push (@errorText, "- $field is too long (31 chars max)");
        }
    }

    if ($SIDfield{'magicID'} eq 'RSID') {
        # Some special checks for RSID.

        if ( (($initAddress > 0) and ($initAddress < 0x07E8)) or
             (($initAddress >= 0xA000) and ($initAddress < 0xC000)) or
             (($initAddress >= 0xD000) and ($initAddress <= 0xFFFF))
           ) {

            push (@errorText, "- initAddress is pointing to a ROM/IO area");
            $initAddressProblem = 1;
        }

        if (!$C64BASIC and (($initAddress < $realLoadAddress) or ($initAddress > $loadRangeEnd)) ) {

            push (@errorText, "- initAddress is outside the load range");
            $initAddressProblem = 1;
        }

        if ($realLoadAddress < 0x07E8) {
            push (@errorText, '- actual load address must not be less than $07E8');
        }

        if ($playAddress != 0) {
            push (@errorText, '- playAddress must be $0000');
            $playAddressProblem = 1;
        }

        if ($speed != 0) {
            push (@errorText, '- speed must be 0x00000000');
            $speedProblem = 1;
        }
    }

    if ($SIDfield{'magicID'} eq 'PSID') {
        if (($initAddress < $realLoadAddress) or ($initAddress > $loadRangeEnd)) {

            push (@errorText, "- initAddress is outside the load range");
            $initAddressProblem = 1;
        }
    }

    if (($SIDfield{'version'} == 2) and ($startPage != 0)) {

        # Reloc info must not overlap or encompass load image.

        if ( ($startPage >= $realLoadAddress) and ($startPage <= $loadRangeEnd) ) {
            push (@errorText, "- startPage is within the load range of the data");
        }

        if ( ($startPage + $pageLength - 1 >= $realLoadAddress) and ($startPage + $pageLength - 1 <= $loadRangeEnd) ) {
            push (@errorText, "- the end of the relocation range (startPage+pageLength) is within the load range of the data");
        }

        if ( ($startPage < $realLoadAddress) and ($startPage + $pageLength - 1 > $loadRangeEnd) ) {
            push (@errorText, "- the relocation range includes the load range of the data");
        }

        # Reloc info must not overlap or encompass the ROM/IO and
        # reserved memory areas.

        if ( (($startPage >= 0xA000) and ($startPage < 0xC000)) or
             (($startPage >= 0xD000) and ($startPage < 0xFF00)) or
             (($startPage > 0x0000) and ($startPage < 0x0400)) ) {

            push (@errorText, "- startPage is within the ROM/IO or reserved memory areas");
        }

        if ( (($startPage + $pageLength - 1 >= 0xA000) and ($startPage + $pageLength - 1 < 0xC000)) or
             (($startPage + $pageLength - 1 >= 0xD000) and ($startPage  + $pageLength - 1 <= 0xFFFF)) or
             (($startPage + $pageLength - 1 > 0x0000) and ($startPage + $pageLength - 1 < 0x0400)) ) {

            push (@errorText, "- the end of the relocation range (startPage+pageLength) is within the ROM/IO or reserved memory areas");
        }

        if ( ($startPage < 0xA000) and ($startPage + $pageLength - 1 >= 0xC000) ) {

            push (@errorText, "- the relocation range encompasses a ROM/IO area");
        }
    }

    if (@errorText) {
        $errorText = "ERROR(S) were found:\n\n";
        $errorText .= join("\n", @errorText);
        $errorText .= ".\n\nCorrect these errors?\n(NOTE: invalid startPage and pageLength values cannot always be corrected!)";

        if (YesNoBox($errorText, 'Invalid fields')) {

            # Correct problems.
            CheckVersion();
            CheckSongs();
            CheckStartSong();

            if (($filename eq '<NONE>') or ($filename =~ /^\s*$/)) {
                $filename = "Unknown.sid";
            }

            if ($initAddressProblem) {
                $SIDfield{'initAddress'} = sprintf('$%04X', $realLoadAddress);
            }

            if ($playAddressProblem) {
                $SIDfield{'playAddress'} = sprintf('$%04X', 0);
            }

            if ($speedProblem) {
                $SIDfield{'speed'} = sprintf('0x%08X', 0);
            }

            foreach (@textFields) {
                CheckTextLength($_);
            }

            foreach $field (@hexFields) {
                $SIDfield{$field} = sprintf("0x%04X", HexValue($SIDfield{$field}, 4));
            }

            foreach $field (@shorthexFields) {
                $SIDfield{$field} = sprintf('$%02X', HexValue($SIDfield{$field}, 2));
            }

            foreach $field (@longhexFields) {
                $SIDfield{$field} = sprintf("0x%08X", HexValue($SIDfield{$field}, 8));
            }

            foreach $field (@c64hexFields) {
                $SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4));
            }
            $fieldsNotValid = 0;
        }
        else {
            $fieldsNotValid = 1;
        }
    }

    return $fieldsNotValid;
}

# Ugly hack, but it works.
sub RecalcMD5 {
    # We create a temporary SID object in order to calculate the MD5 over it.
    my $tempSID = new Audio::SID();
    my $field;

    $mySID->set('version', $SIDfield{'version'});

    foreach $field (@SIDfields) {
        next if ($field eq 'data');
        next if (($field eq 'magicID') and ($SIDfield{'version'} == 1));

        if (grep(/^$field$/, @hexFields) or
            grep(/^$field$/, @c64hexFields)) {

            next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
            # Get data out of the hex fields.
            $tempSID->set($field, HexValue($SIDfield{$field}, 4));
        }
        elsif (grep(/^$field$/, @longhexFields)) {
            next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
            # Get data out of the hex fields.
            $mySID->set($field, HexValue($SIDfield{$field}, 8));
        }
        elsif (grep(/^$field$/, @shorthexFields)) {
            next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
            # Get data out of the hex fields.
            $mySID->set($field, HexValue($SIDfield{$field}, 2));
        } else {
            $tempSID->set($field, $SIDfield{$field});
        }
    }

    $tempSID->set('data', $mySID->get('data'));

    # We did all of the above just for this:
    $SIDMD5 = $tempSID->getMD5();
}

##############################################################################
#
# Building main window
#
##############################################################################

# Pass in widget name.
sub BuildWindow($) {
    my ($widget) = @_;
    my $dirlistframe;
    my $SIDdataframe;
    my $statusframe;
    my $windowframe;

    # Create tooltips, left justified.
    $tooltip = $window->Balloon();
    $tooltip->Subwidget('message')->configure(-justify => 'left');

    $windowframe = $widget->Frame
        ->pack(@topPack, @bothFill, @expand);

    # Create the dirlist subframe.
    $dirlistframe = $windowframe->Frame
        ->pack(@leftPack, @bothFill, @expand);

    # Dir + file listing.
    BuildFileSelBox($dirlistframe);

    # Create the SID data subframe.
    $SIDdataframe = $windowframe->Frame
        ->pack(@rightPack, @bothFill);

    $statusframe = $widget->Frame(-borderwidth => '2', -relief => 'sunken')
        ->pack(@bottomPack, @xFill);
    $statusbar = $statusframe->Label(-textvariable => \$STATUS)
        ->pack(@leftPack, @xFill);

    BuildSIDheaderBox($SIDdataframe);

    BuildMenu();
    BuildToolBar();

    SetupBindings();
    PopulateSIDfields();
    ScanDir(1);
}

# Pass in widget name.
sub BuildFileSelBox($) {
    my ($widget) = @_;
    my $dirlistframe;
    my $leftframe;
    my $rightframe;
    my $checkframe;
    my $subcheckframe;
    my $dirnameframe;
    my $dirTopframe;
    my $tempwidget;
    my $dirnavframe;
    my $toolbar;

    $dirlistframe = $widget->LabFrame(-label => "File navigator",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill, @expand);

    $dirTopframe = $dirlistframe->Frame
        ->pack(@topPack, @bothFill);

    # Directory navigational buttons.

    $dirnavframe = $dirTopframe->Frame
        ->pack(@topPack, @bothFill);

    $toolbar = $dirnavframe->ToolBar(-movable => 0, -side => 'top', -cursorcontrol => 0);

    $toolbar->ToolButton(-image => 'navup16',  -tip => "Open parent directory", -command => [\&ChangeToDir, '..']);
    $toolbar->ToolButton(-image => 'navhome16', -tip => "Go to default directory", -command => [\&ChangeToDir, \$DefaultDirectory]);
    $toolbar->ToolButton(-image => 'folderopen16', -tip => "Go to save directory", -command => [\&ChangeToDir, \$SaveDirectory]);
    $toolbar->ToolButton(-image => 'HVSC_icon', -tip => "Go to HVSC directory", -command => [\&ChangeToDir, \$HVSCDirectory]);
    $toolbar->separator(-movable => 0);
    $toolbar->ToolButton(-image => 'foldernew16', -tip => "Create new directory", -command => [\&MakeDir]);
    $toolbar->ToolButton(-image => 'edittrash16', -tip => "Delete selected directory", -command => [\&DeleteDir]);

    # Add pathname entry.

    $dirnameframe = $dirTopframe->Frame
        ->pack(@topPack, @bothFill);

    if ($isWindows) {
        $dirnameframe->Label(-text => 'Drive:')
            ->pack(@leftPack);

        $drivelistbox = $dirnameframe->Optionmenu();

        foreach (getLogicalDrives()) {
            s/\\$//; # Get rid of hanging root dir.
            $_ = uc($_);
            $drivelistbox->addOptions([$_ => $_]);
        }

        $drivelistbox->setOption($drive); # Sets default option.
        $drivelistbox->configure(
            -variable => \$drive,
            -command => sub {ChangeToDir($drive);} );

        $drivelistbox->pack(@leftPack);
    }

    $dirnameframe->Label(-text => 'Directory:')
        ->pack(@leftPack);
    $direntry = $dirnameframe->Entry(-textvariable => \$directory, -width => 46)
        ->pack(@rightPack, @xFill, @expand);
    $tooltip->attach($direntry, -msg => \$directory);

    # Add listing options.
    $checkframe = $dirTopframe->Frame
        ->pack(@topPack, @bothFill);

    $checkframe->Checkbutton(@noBorder,
            -text => "List SID files",
            -variable => \$ListSIDFiles,
            -command => sub {ScanDir(1);})
        ->pack(@leftPack);
    $checkframe->Checkbutton(@noBorder,
            -text => "List C64 data files",
            -variable => \$ListDataFiles,
            -command => sub {ScanDir(1);})
        ->pack(@leftPack);
    $checkframe->Checkbutton(@noBorder,
            -text => "List INFO files",
            -variable => \$ListInfoFiles,
            -command => sub {ScanDir(1);})
        ->pack(@leftPack);
    $checkframe->Checkbutton(@noBorder,	# XXX
            -text => "List all files",
            -variable => \$ListAllFiles,
            -command => sub {ScanDir(1);})
        ->pack(@leftPack);

    # Create left and right subframes for dir/file selection.
    # Also create the scrolled listboxes in them.
    $dirlistbox = $dirlistframe->Scrolled("Listbox", -scrollbars => 'osoe', @raised, -exportselection => 0)
        ->pack(@leftPack, @expand, @bothFill);
    $filelistbox = $dirlistframe->Scrolled("Listbox", -scrollbars => 'osoe', @raised, -exportselection => 0)
        ->pack(@rightPack, @expand, @bothFill);

    # Add right-click popup menu.
#   BuildFileNavPopupMenu();
#   $filelistbox->bind('<ButtonPress-3>', [sub {
#       $filelistbox->eventGenerate('<ButtonPress-1>');
#       $window->idletasks();
#       PostPopup($_[0], $_[1], $_[2]);
#   }, Ev('X'), Ev('Y')] );

    # Mousewheel support - experimental.
    $dirlistbox->bind("<4>", ['yview', 'scroll', +5, 'units']);
    $dirlistbox->bind("<5>", ['yview', 'scroll', -5, 'units']);
    $dirlistbox->bind('<MouseWheel>',
              [ sub { $_[0]->yview('scroll',-($_[1]/120)*3,'units') }, Tk::Ev("D")]);

    # Mousewheel support - experimental.
    $filelistbox->bind("<4>", ['yview', 'scroll', +5, 'units']);
    $filelistbox->bind("<5>", ['yview', 'scroll', -5, 'units']);
    $filelistbox->bind('<MouseWheel>',
              [ sub { $_[0]->yview('scroll',-($_[1]/120)*3,'units') }, Tk::Ev("D")]);
}

# Pass in widget name.
sub BuildSIDheaderBox($) {
    my($widget) = @_;
    my $upperframe;
    my $row = 0;
    my $filenamelabel;
    my $tempwidget;
    my $SIDtopframe;
    my $buttonframe;
    my $mybutton;

    $upperframe = $widget->LabFrame(-label => "File info",
        -labelside => 'acrosstop')
        ->pack(@topPack, @bothFill);

    $filenamelabel = $upperframe->Label(-text => "Filename:")
            ->grid(-column => 0, -row => $row, -sticky => 'e');
    $tooltip->attach($filenamelabel, -msg => "To rename the file, change\nfilename here then save.");
    $filenameentry = $upperframe->Entry(-textvariable => \$filename, -width => 32)
            ->grid(-column => 1, -row => $row, -sticky => 'w');
    $filenameentry->bind("<Key>", sub {$modified = 1;});
    $tooltip->attach($filenameentry, -msg => "To rename the file, change\nfilename here then save.");
    $tempwidget = $upperframe->Checkbutton(@noBorder,
                -text => '',
                -variable => \$copy{'filename'},
                -takefocus => 0)
            ->grid(-column => 2, -row => $row++, -sticky => 'w');
    $tooltip->attach($tempwidget, -msg => "Allow copy/paste of filename?");

    $tempwidget = $upperframe->Label(-text => "File size:")
            ->grid(-column => 0, -row => $row, -sticky => 'e');
    $tooltip->attach($tempwidget, -msg => "Projected size of file\nif it was saved right now.");
    $tempwidget = $upperframe->Label(-textvariable => \$filesize)
            ->grid(-column => 1, -row => $row, -sticky => 'w');
    $tooltip->attach($tempwidget, -msg => "Projected size of file\nif it was saved right now.");
    $tempwidget = $upperframe->Checkbutton(@noBorder,
                -text => '',
                -variable => \$copy{'filesize'},
                -takefocus => 0)
            ->grid(-column => 2, -row => $row++, -sticky => 'w');
    $tooltip->attach($tempwidget, -msg => "Allow copy of filesize?");

    $tempwidget = $upperframe->Label(-text => "MD5 fingerprint:")
            ->grid(-column => 0, -row => $row, -sticky => 'e');
    $tooltip->attach($tempwidget, -msg => "Usually used to index into\nthe songlength database.");
    $tempwidget = $upperframe->Label(-textvariable => \$SIDMD5)
            ->grid(-column => 1, -row => $row, -sticky => 'w');
    $tooltip->attach($tempwidget, -msg => "Usually used to index into\nthe songlength database.");
    $tempwidget = $upperframe->Checkbutton(@noBorder,
                -text => '',
                -variable => \$copy{'MD5'},
                -takefocus => 0)
            ->grid(-column => 2, -row => $row++, -sticky => 'w');
    $tooltip->attach($tempwidget, -msg => "Allow copy of MD5 fingerprint?");

    # Add misc. buttons.
    $buttonframe = $widget->Frame
        ->pack(@topPack, @bothFill);

    $buttonframe->Button(-text => "Create HVSC\ncompliant filename", -command => \&HVSCLongFilename, -underline => 7)
        ->grid(-column => 0, -row => 0, -padx => 5);

    $buttonframe->Button(
            -text => "Display SID data",
            -command => \&ShowSIDData,
            -underline => 1 )
       ->grid(-column => 1, -row => 0, -padx => 5, -sticky => 'ns');

    $buttonframe->Button(
            -textvariable => \$showAllButtonText,
            -command => [\&ShowFields, 1],
            -underline => 0,
            -width => 15)
        ->grid(-column => 2, -row => 0, -padx => 5, -sticky => 'ns');

    $SIDtopframe = $widget->LabFrame(-label => "SID header",
        -labelside => 'acrosstop')
        ->pack(@topPack, @bothFill);
    # I don't know why, but LabFrame() doesn't seem to have gridForget()...
    $SIDframe = $SIDtopframe->Frame()
        ->pack(@topPack, @bothFill);

    AddSIDfields();
}

sub BuildMenu {
    my $menubar;
    my @tempSIDfields;
    my $i = 0;

    # Get rid of 'data' from the field list.
    # I wonder if there's a more elegant way to do this...
    foreach (@SIDfields) {
        $tempSIDfields[$i++] = $_ if ($_ ne 'data');
    }

    $menubar = $window->toplevel->Menu(-type => 'menubar');
    $window->toplevel->configure(-menu => $menubar);

    my $f = $menubar->Menubutton(-text => '~File', -tearoff => 0, -menuitems =>
    [
        [Button => '~New',        -command => [\&NewFile], -accelerator => 'Ctrl+N'],
#        [Button => '~Open...',    -command => [\&none], -accelerator => 'Ctrl+O', -state => 'disabled'],
        [Button => '~Save',       -command => [\&Save, 0],   -accelerator => 'Ctrl+S'],
        [Button => 'Save ~As...', -command => [\&SaveAs],    -accelerator => 'Ctrl+A'],
        [Button => 'De~lete selected file', -command => [\&Delete],    -accelerator => 'Ctrl+L, Delete'],
        [Separator => ''],
        [Button => '~Go to default directory', -command => [\&ChangeToDir, $DefaultDirectory],    -accelerator => 'Shift+Home'],
        [Button => 'Go to save ~directory', -command => [\&ChangeToDir, $SaveDirectory],    -accelerator => 'Ctrl+Home'],
        [Button => 'Go to ~HVSC directory', -command => [\&ChangeToDir, $HVSCDirectory],    -accelerator => 'Alt+Home'],
        [Separator => ''],
        [Button => 'C~reate new directory', -command => [\&MakeDir],    -accelerator => 'Ctrl+R'],
        [Button => 'D~elete selected directory', -command => [\&DeleteDir],    -accelerator => 'Ctrl+E, Delete'],
        [Separator => ''],
        [Button => '~Quit',       -command => [\&Quit],         -accelerator => 'Ctrl+Q, Escape'],
    ]);

    my $e = $menubar->Menubutton(-text => '~Edit', -tearoff => 0, -menuitems =>
    [
        [Button => '~Copy',       -command => [\&CopyToClipboard], -accelerator => 'Ctrl+C'],
        [Button => '~Paste',      -command => [\&PasteFromClipboard], -accelerator => 'Ctrl+V'],
        [Separator => ''],
        [Cascade => 'Copy ~format', -tearoff => 0, -menuitems =>
            [
                [Checkbutton => 'Copy ~selected fields only', -variable => \$CopyHow, -onvalue => 'selected'],
                [Checkbutton => 'Copy ~all fields',           -variable => \$CopyHow, -onvalue => 'all'],
                [Checkbutton => 'Copy SIDPlay ~INFO style',   -variable => \$CopyHow, -onvalue => 'info_style'],
            ]
        ],
        [Cascade => 'Cop~y field selection', -tearoff => 0, -menuitems =>
            [
                [Checkbutton => 'Filename',  -variable => \$copy{'filename'}, -onvalue => 1, -offvalue => 0],
                [Checkbutton => 'File size', -variable => \$copy{'filesize'}, -onvalue => 1, -offvalue => 0],
                [Checkbutton => 'MD5',       -variable => \$copy{'MD5'}, -onvalue => 1, -offvalue => 0],
                map (
                    [Checkbutton => $_,      -variable => \$copy{$_}, -onvalue => 1, -offvalue => 0],
                    @tempSIDfields
                )
            ]
        ],
        [Checkbutton => 'Paste to ~selected fields only', -variable => \$PasteSelectedOnly],
    ]);

    my $t = $menubar->Menubutton(-text => '~Tools', -tearoff => 0, -menuitems =>
    [
        [Button => 'Create ~HVSC compliant filename', -command => [\&HVSCLongFilename], -accelerator => 'Ctrl+H'],
        [Button => '~Display SID data', -command => [\&ShowSIDData], -accelerator => 'Ctrl+D'],
        [Separator => ''],
        [Button => '~Play SID file...',              -command => [\&LaunchApp, 'SID player'], -accelerator => 'Ctrl+P'],
        [Button => 'Edit file with he~x editor...',  -command => [\&LaunchApp, 'hex editor'], -accelerator => 'Ctrl+X'],
        [Button => 'Run command line ~tool...',      -command => [\&RunTool], -accelerator => 'Ctrl+T'],
        [Button => 'Show last ~output of tool...',   -command => [\&ShowLastToolOutput, $window], -accelerator => 'Ctrl+O'],
        [Separator => ''],
        [Button => 'Confi~gure settings...',   -command => [\&Settings], -accelerator => 'Ctrl+G'],
    ]);

    # This right-justifies the Help menu.
    # NOTE: But it also leaves a small dot...
    $menubar->Separator(0);

    my $b = $menubar->Menubutton(-text => '~Help', -tearoff => 0, -menuitems =>
    [
        [Button => '~Quick tutorial...',  -command => [\&ShowHelp], -accelerator => 'F1'],
        [Button => '~SID file format description...', -command => [\&ShowTextBox, $window, 'SID file format description', 'load', $SID_FORMAT]],
#        [Button => '~C64 assembly codes...',  -command => [\&ShowAssemblyCodes]],
        [Separator => ''],
        [Button => "~About SIDedit...", -command => [\&About]],
    ]);
}

sub BuildFileNavPopupMenu {

    $fileNavPopupMenu = $window->Menu(-type => 'popup', -tearoff => 0, -popover => 'cursor');

    $fileNavPopupMenu->command(-label => 'D~isplay SID data', -command => [\&ShowSIDData]);
    $fileNavPopupMenu->Separator();
    $fileNavPopupMenu->command(-label => 'P~lay SID file...', -command => [\&LaunchApp, 'SID player']);
    $fileNavPopupMenu->command(-label => 'Edit file with he~x editor...', -command => [\&LaunchApp, 'hex editor']);
    $fileNavPopupMenu->command(-label => 'Run command line ~tool...', -command => [\&RunTool]);
    $fileNavPopupMenu->Separator();
    $fileNavPopupMenu->command(-label => '~Delete file', -command => [\&Delete]);
}

sub PostPopup {
    my ($w, $X, $Y) = @_;
    $fileNavPopupMenu->Post($X-10,$Y-10);
}

sub BuildToolBar {
    my $toolbar;

    $toolbar = $window->ToolBar(-movable => 0, -side => 'top');

    $toolbar->ToolButton(-image => 'filenew16',  -tip => "New file (initialize SID data)", -command => [\&NewFile]);
    $toolbar->ToolButton(-image => 'devfloppyunmount16', -tip => "Save file", -command => [\&Save, 0]);
    $toolbar->ToolButton(-image => 'devfloppymount16', -tip => "Save as...", -command => [\&SaveAs]);
    $toolbar->ToolButton(-image => 'actcross16', -tip => "Delete file", -command => [\&Delete]);
    $toolbar->separator(-movable => 0);
    $toolbar->ToolButton(-image => 'editcopy16', -tip => "Copy to clipboard", -command => [\&CopyToClipboard]);
    $toolbar->ToolButton(-image => 'editpaste16', -tip => "Paste from clipboard", -command => [\&PasteFromClipboard]);
    $toolbar->separator(-movable => 0);
    $toolbar->ToolButton(-image => 'actreload16', -tip => "Toggle field display", -command => [\&ShowFields, 1]);
    $toolbar->ToolButton(-image => 'filefind16', -tip => "Display SID data", -command => [\&ShowSIDData]);
    $toolbar->ToolButton(-image => 'apppencil16', -tip => "Create HVSC compliant filename", -command => [\&HVSCLongFilename]);
    $toolbar->separator(-movable => 0);
    $toolbar->ToolButton(-image => 'devspeaker16', -tip => "Play SID file\n(You can also double-click\non files to play them.)", -command => [\&LaunchApp, 'SID player']);
    $toolbar->ToolButton(-image => 'edit16', -tip => "Edit file with hex editor", -command => [\&LaunchApp, 'hex editor']);
    $toolbar->ToolButton(-image => 'apptool16', -tip => "Run command line tool\nwith selected file", -command => [\&RunTool]);
    $toolbar->ToolButton(-image => 'devscreen16', -tip => "Show the last output\nof the command line tool", -command => [\&ShowLastToolOutput, $window]);
    $toolbar->separator(-movable => 0);
    $toolbar->ToolButton(-image => 'actrun16', -tip => "Configure settings", -command => [\&Settings]);
    $toolbar->ToolButton(-image => 'acthelp16', -tip => "Help (quick tutorial)", -command => [\&ShowTextBox, $window, 'Quick tutorial', 'load', $SIDEDIT_POD]);
}

# If value passed in is TRUE, sets $ShowAllFields, otherwise it doesn't.
sub ShowFields($) {
    my ($setValue) = @_;

    if ($setValue) {
        if ($ShowAllFields) {
            $ShowAllFields = 0;
            $showAllButtonText = "Show all fields";
        }
        else {
            $ShowAllFields = 1;
            $showAllButtonText = "Show credits only";
        }
    }
    else {
        if ($ShowAllFields) {
            $showAllButtonText = "Show credits only";
        }
        else {
            $showAllButtonText = "Show all fields";
        }
    }

    # Get rid of all subwidgets.
    $SIDframe->gridForget($SIDframe->gridSlaves());

    # ...And redo them from scratch.
    AddSIDfields();
    UpdateV2Fields();
    UpdateMagicIDFields();
    UpdateFlags();
    $window->update();
}

sub RecalcFlags {
    $modified = 1;
    $SIDfield{'flags'} = HexValue($SIDfield{'flags'}, 4);
    $SIDfield{'flags'} &= ~(0x1 << $PLAYSID_OFFSET);
    $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});
    CheckMagicID();
}

sub AddSIDfields {
    my $row;
    my $field;
    my $entry;
    my $tempwidget;

    $row=1;
    foreach $field (@SIDfields) {
        # Don't allow edit of this field here.
        next if ($field eq 'data');

        unless ($ShowAllFields) {
            next if (($field ne 'name') and ($field ne 'released') and
                ($field ne 'author'));
        }

        if ($field eq 'magicID') {
            $SIDframe->Label(-text => "Environment:")
                ->grid(-column => 0, -row => $row, -sticky => 'e');
        }
        else {
            $SIDframe->Label(-text => "$field:")
                ->grid(-column => 0, -row => $row, -sticky => 'e');
        }

        if ($field eq 'magicID') {
            $magicIDButtonPSID = $SIDframe->Radiobutton(@noBorder,
                    -text => "PlaySID",
                    -variable => \$SIDfield{'magicID'},
                    -command => sub {RecalcFlags(); },
                    -value => 'PSID')
                ->grid(-column => 1, -row => $row, -sticky => 'ew');
            $tooltip->attach($magicIDButtonPSID, -msg => "The rip is PlaySID compatible.");

            $magicIDButtonRSID = $SIDframe->Radiobutton(@noBorder,
                    -text => "Real C64",
                    -variable => \$SIDfield{'magicID'},
                    -command => sub {RecalcFlags(); },
                    -value => 'RSID')
                ->grid(-column => 2, -row => $row, -sticky => 'ew');
            $tooltip->attach($magicIDButtonRSID, -msg => "Absolutely requires a true C64\nenvironment to play properly.");
        }
        elsif ($field eq 'version') {
            $version1Button = $SIDframe->Radiobutton(@noBorder,
                    -text => "v1",
                    -variable => \$SIDfield{'version'},
                    -command => sub {$modified = 1; CheckVersion(); },
                    -value => '1')
                ->grid(-column => 1, -row => $row, -sticky => 'ew');

            $version2Button = $SIDframe->Radiobutton(@noBorder,
                    -text => "v2/v2NG",
                    -variable => \$SIDfield{'version'},
                    -command => sub {$modified = 1; CheckVersion(); },
                    -value => '2')
                ->grid(-column => 2, -row => $row, -sticky => 'ew');
        }
        elsif ($field eq 'speed') {
            $entry = $SIDframe->Entry(
                    -textvariable => \$SIDfield{$field},
                    -width => 11,
                    -foreground => 'darkred')
                ->grid(-column => 1, -row => $row, -sticky => 'w');
            $speedEditButton = $SIDframe->Button(
                    -text => 'Edit speed bits',
                    -command => \&EditSpeed,
                    -underline => 11)
                ->grid(-column => 2, -row => $row, -sticky => 'ew');
        }
        elsif ($field eq 'flags') {
            $entry = $SIDframe->Entry(
                    -textvariable => \$SIDfield{$field},
                    -width => 11,
                    -foreground => 'darkred')
                ->grid(-column => 1, -row => $row, -sticky => 'w');
            $flagsEditButton = $SIDframe->Button(
                    -text => 'Edit the flags',
                    -command => \&EditFlags,
                    -underline => 9)
                ->grid(-column => 2, -row => $row, -sticky => 'ew');
            $flagsEntry = $entry;
        }
        else {
            $entry = $SIDframe->Entry(
                    -textvariable => \$SIDfield{$field},
                    -width => 32)
                ->grid(-column => 1, -columnspan => 2, -row => $row, -sticky => 'w');
				
            $ENABLED_ENTRY_COLOR = $entry->cget('background') unless (defined($ENABLED_ENTRY_COLOR));			
            $ENABLED_ENTRY_COLOR = 'black' unless (defined($ENABLED_ENTRY_COLOR));	#XXX
        }

        $tempwidget = $SIDframe->Checkbutton(@noBorder,
                -text => '',
                -variable => \$copy{$field},
                -takefocus => 0)
            ->grid(-column => 3, -row => $row, -sticky => 'w');
        $tooltip->attach($tempwidget, -msg => "Allow copy/paste of $field?");

        if (($field eq 'version') or ($field eq 'magicID')) {
            $row++;
            next;
        }

        if ($field eq 'startPage') {
            $entry->configure(-foreground => 'purple');
            $startPageEntry = $entry;
        }
        elsif ($field eq 'pageLength') {
            $entry->configure(-foreground => 'purple');
            $pageLengthEntry = $entry;
        }
        elsif ($field eq 'reserved') {
            $reservedEntry = $entry;
        }
        elsif ($field eq 'loadAddress') {
            $entry->configure(-foreground => 'darkgreen');
            $loadAddressEntry = $entry;
        }
        elsif ($field eq 'playAddress') {
            $entry->configure(-foreground => 'darkgreen');
            $playAddressEntry = $entry;
        }
        elsif ($field eq 'initAddress') {
            $entry->configure(-foreground => 'darkgreen');
            $initAddressEntry = $entry;
        }
        elsif ($field eq 'songs') {
            $entry->configure(-foreground => 'blue');
        }
        elsif ($field eq 'startSong') {
            $entry->configure(-foreground => 'blue');
        }
        elsif ($field eq 'name') {
            $entry->configure(-foreground => '#ff0000');
        }
        elsif ($field eq 'author') {
            $entry->configure(-foreground => '#dd0000');
        }
        elsif ($field eq 'released') {
            $entry->configure(-foreground => '#bb0000');
        }
        elsif ($field eq 'speed') {
            $speedEntry = $entry;
        }

        # Set up bindings (which are also range checks).

        if ($field eq 'dataOffset') {
            # Special hex field.
            $entry->bind("<Return>", \&CheckDataOffset );
            $entry->bind("<FocusOut>", sub {CheckDataOffset(); $STATUS = '';} );
            $entry->bind("<FocusIn>", sub {$STATUS = 'Hexadecimal field, must be 0x0076 if version is 1, or in the range of 0x007C - 0xFFFF otherwise.';} );
            $dataOffsetEntry = $entry;
        }
        elsif ($field eq 'songs') {
            $entry->bind("<Return>", \&CheckSongs );
            $entry->bind("<FocusOut>", sub {CheckSongs(); $STATUS = '';} );
            $entry->bind("<FocusIn>", sub {$STATUS = 'Decimal field, range is 1 - 256.';} );
        }
        elsif ($field eq 'startSong') {
            $entry->bind("<Return>", \&CheckStartSong );
            $entry->bind("<FocusOut>", sub {CheckStartSong(); $STATUS = '';} );
            $entry->bind("<FocusIn>", sub {$STATUS = 'Decimal field, range is 1 - songs.';} );
        }
        elsif ($field eq 'flags') {
            $entry->bind("<Return>", \&UpdateFlags );
            $entry->bind("<FocusOut>", sub {UpdateFlags(); $STATUS = '';} );
            $entry->bind("<FocusIn>", sub {$STATUS = "Hexadecimal field, range is 0x0000-0x003F.";} );
        }
        elsif (grep(/^$field$/, @hexFields)) {
            # If it's a hex field, update its value when it's out of focus.

            if (grep(/^$field$/, @MD5Fields)) {
                # Editing these fields will update the MD5 fingerprint.
                $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf("0x%04X", HexValue($SIDfield{$field}, 4)); RecalcMD5();} );
                $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf("0x%04X", HexValue($SIDfield{$field}, 4)); RecalcMD5(); $STATUS = '';} );
            }
            else {
                $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf("0x%04X", HexValue($SIDfield{$field}, 4));} );
                $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf("0x%04X", HexValue($SIDfield{$field}, 4)); $STATUS = '';} );
            }
            $entry->bind("<FocusIn>", sub {$STATUS = "Hexadecimal field, range is 0x0000-0xFFFF.";} );
        }
        elsif (grep(/^$field$/, @longhexFields)) {
            # It's a 4-byte hex field.

            if (grep(/^$field$/, @MD5Fields)) {
                # Editing these fields will update the MD5 fingerprint.
                $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf("0x%08X", HexValue($SIDfield{$field}, 8)); RecalcMD5(); } );
                $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf("0x%08X", HexValue($SIDfield{$field}, 8)); RecalcMD5();  $STATUS = '';} );
            }
            else {
                $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf("0x%08X", HexValue($SIDfield{$field}, 8));} );
                $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf("0x%08X", HexValue($SIDfield{$field}, 8)); $STATUS = '';} );
            }
            $entry->bind("<FocusIn>", sub {$STATUS = "Hexadecimal field, range is 0x00000000-0xFFFFFFFF.";} );
        }
        elsif (grep(/^$field$/, @shorthexFields)) {
            # It's a 1-byte hex field.

            $entry->bind("<Return>", \&CheckRelocInfo );
            $entry->bind("<FocusOut>", sub {CheckRelocInfo(); $STATUS = '';} );
            $entry->bind("<FocusIn>", sub {$STATUS = 'Hexadecimal field, range is $00-$FF.';} );
        }
        elsif (grep(/^$field$/, @c64hexFields)) {
            # If it's a hex field, update its value when it's out of focus.

            if (grep(/^$field$/, @MD5Fields)) {
                # Editing these fields will update the MD5 fingerprint.
                $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4)); RecalcMD5(); } );
                $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4)); RecalcMD5(); $STATUS = '';} );
            }
            else {
                $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4));} );
                $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4)); $STATUS = '';} );
            }
            $entry->bind("<FocusIn>", sub {$STATUS = 'Hexadecimal field, range is $0000-$FFFF.';} );
        }
        elsif ($field eq 'name') {
            $entry->bind("<Return>", sub { CheckTextLength($field); HVSCLongFilename() if ($AutoHVSCFilename); } );
            $entry->bind("<FocusOut>", sub { CheckTextLength($field); HVSCLongFilename() if ($AutoHVSCFilename); } );
            $entry->bind("<FocusIn>", sub {$STATUS = "Text field, maximum length is 31 characters.";} );
        }
        else {
            # Plain text.
            $entry->bind("<Return>", sub { CheckTextLength($field) } );
            $entry->bind("<FocusOut>", sub { CheckTextLength($field); $STATUS = ''; } );
            $entry->bind("<FocusIn>", sub {$STATUS = "Text field, maximum length is 31 characters.";} );
        }

        # Set up tooltips (mostly).

        if ($field eq "loadAddress") {
            $entry->bind("<Return>", sub {$SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4)); UpdateLoadAddress(); } );
            $entry->bind("<FocusOut>", sub {$SIDfield{$field} = sprintf('$%04X', HexValue($SIDfield{$field}, 4)); UpdateLoadAddress(); $STATUS = '';} );
            $entry->bind("<FocusIn>", sub {$STATUS = 'Hexadecimal field, range is $0000-$FFFF. Prefered value is 0.';} );
            $tooltip->attach($entry, -msg => "Prefered value is 0 with the actual\nload address in the first 2 bytes of 'data'.\nThis is enforced when always saving as v2NG.");

            # Display load range right below loadAddress.
            $row++;

            $tempwidget= $SIDframe->Label(-text => "Load range:")
                ->grid(-column => 0, -row => $row, -sticky => 'e');
            $tooltip->attach($tempwidget, -msg => "Where the C64 data will be loaded to.");
            $tempwidget = $SIDframe->Label(-textvariable => \$loadRange)
                ->grid(-column => 1, -row => $row, -sticky => 'w');
            $tooltip->attach($tempwidget, -msg => "Where the C64 data will be loaded to.");
        }
        elsif ($field eq "initAddress") {
            $tooltip->attach($entry, -msg => "A 0 here means initAddress is equal\nto the actual load address.");
        }
        elsif ($field eq "playAddress") {
            $tooltip->attach($entry, -msg => "A 0 here means the init routine is\nexpected to install an interrupt handler\nwhich then calls the music player.");
        }
        elsif ($field eq "author") {
            $tooltip->attach($entry, -msg => "Suggested forms:\n'John Doe (Nick)', 'J.F. Doe/GRP',\n'John Doe & Jane Dough'");
        }
        elsif ($field eq "released") {
            $tooltip->attach($entry, -msg => "Suggested forms:\n'1991 John Doe', '1991 Awesome Group',\n'1991 Fictional Software'");
        }
        elsif ($field eq "startPage") {
            $entry->bind("<FocusIn>", sub {$STATUS = 'Hexadecimal field, range is $00-$FF. $00 indicates a clean SID, $FF indicates no free pages.';} );
            $tooltip->attach($entry, -msg => "Specifies the start page of the\nsingle largest free memory range\nwithin the driver ranges.\n\$00 indicates a clean rip,\n\$FF indicates no free pages at all.");
        }
        elsif ($field eq "pageLength") {
            $entry->bind("<FocusIn>", sub {$STATUS = 'Hexadecimal field, range is $00-$FF.';} );
            $tooltip->attach($entry, -msg => "Specifies the number of free pages\nstarting at startPage.");
        }
        elsif ($field eq "reserved") {
            # $reservedEntry->configure(-state => 'disabled');
            $tooltip->attach($entry, -msg => "Should be set to 0.");
        }

        # Setup these bindings so we know when a field got changed.

        # CTRL and ALT modified keypresses don't modify a field.
        $entry->bind("<Control-Key>", sub {} );
        $entry->bind("<Alt-Key>", sub {} );
        $entry->bind("<Delete>", sub {$modified = 1} );
        $entry->bind("<BackSpace>", sub {$modified = 1} );
        $entry->bind("<Key>", [sub {
                my $unused = shift;
                my $key = shift;

                # Mark it modified only when a non-modifier key was pressed.
                $modified = 1 if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
            }, Ev('K')] );
        $row++;
    }
}

sub UpdateV2Fields {

    return unless ($ShowAllFields);

    if ($SIDfield{'version'} == 1) {
        $magicIDButtonPSID->configure(-state => 'disabled');
        $magicIDButtonRSID->configure(-state => 'disabled');
        $dataOffsetEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $flagsEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $flagsEditButton->configure(-state => 'disabled');
        $startPageEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $pageLengthEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $reservedEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
    }
    else {
        $magicIDButtonPSID->configure(-state => 'normal');
        $magicIDButtonRSID->configure(-state => 'normal');
        $dataOffsetEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $flagsEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $flagsEditButton->configure(-state => 'normal');
		
        $startPageEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $pageLengthEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $reservedEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
    }
}

sub UpdateMagicIDFields {

    return unless ($ShowAllFields);

    if ($SIDfield{'magicID'} eq 'RSID') {
        $version1Button->configure(-state => 'disabled');
        $version2Button->configure(-state => 'disabled');
        $loadAddressEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $playAddressEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $speedEntry->configure(-state => 'disabled', -background => $DISABLED_ENTRY_COLOR);
        $speedEditButton->configure(-state => 'disabled');
        $PlaySIDButtonState = 'disabled';
        $C64BASICButtonState = 'normal';
    }
    else {
        $version1Button->configure(-state => 'normal');
        $version2Button->configure(-state => 'normal');
        $loadAddressEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $playAddressEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $initAddressEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $speedEntry->configure(-state => 'normal', -background => $ENABLED_ENTRY_COLOR);
        $speedEditButton->configure(-state => 'normal');
        $PlaySIDButtonState = 'normal';
        $C64BASICButtonState = 'disabled';
    }
}

##############################################################################
#
# Pop-up windows
#
##############################################################################

# Returns TRUE if the calling function should not move on.
sub SaveChanges {
    my $answer = 0;

    if ($modified) {
        $answer = YesNoBox('SID file has changed. Do you want to save your changes first?', 'SID file has changed');

        if ($answer) {
            if (SaveAs(1)) {
                return 0;
            }
            else {
                return 1;
            }
        }
    }

    return $answer;
}

# First param: optional text to display, second param:  optional title for the pop-up window.
# Returns TRUE if answer is 'yes'.
sub YesNoBox {
    my ($text, $title) = @_;
    my $dialog;
    my $answer;

    $STATUS = "";

    # Some default values just in case.
    $text ||= 'Well?';
    $title ||= 'Yes or no?';

    # For some reason under WinCrap if you select the Yes button with Tab and
    # press Enter on it, it doesn't work...
    $dialog = $window->Dialog(
        -text => $text,     -bitmap => 'question',
        -title => 'SIDedit - ' . $title,   -default_button => "No",
        -buttons => ["Yes","No"]);

    $dialog->protocol('WM_DELETE_WINDOW', undef);

    # Stupid dialog box doesn't provide default key-bindings.
    foreach ($dialog->children()) {
        if ($_->name() eq "bottom") {
            foreach $wid ($_->children()) {
                if ($wid->name() =~ /button/i) {
                    $wid->configure(-underline => 0);
                }
            }
        }
    }

    # This is a _VERY_ ugly hack:
    $dialog->bind("<y>", sub {$dialog->{'selected_button'} = "Yes";} );
    $dialog->bind("<n>", sub {$dialog->{'selected_button'} = "No";} );
    $dialog->bind("<Y>", sub {$dialog->{'selected_button'} = "Yes";} );
    $dialog->bind("<N>", sub {$dialog->{'selected_button'} = "No";} );

    $answer = $dialog->Show();

    if ($answer eq "Yes") {
        return 1;
    }
    return 0;
}

# First param: text to display, second param: optional title for window.
sub ErrorBox {
    my ($text, $title) = @_;
    my $dialog;

    unless ($title) {
        $title = "ERROR!";
    }

    $dialog = $window->Dialog(
        -text => $text,
        -title => 'SIDedit - ' . $title);

    # This is cewl. 8-)
    $dialog->bell();

    $dialog->protocol('WM_DELETE_WINDOW', undef);
    $dialog->Show();
}

# Display standard errors in a window.
sub Tk::Error
{
    my ($widget,$error,@locations) = @_;

    # Display just the error text itself.
    ErrorBox($error);
}

sub About {
    my $dialog;
    my $text;
    my $row = 1;
    my $using;
    my @boldFont;
    my @bigFont;

    if ($isWindows) {
        @boldFont = (-family => 'systemfixed');
        @bigFont  = (-family => 'systemfixed');
    }

    push (@boldFont, (-weight => 'bold', => -size => '8'));
    push (@bigFont, (-weight => 'bold', -size => '12'));

    $text  = "\nInstruction definitions for disassembler lifted from Michael Schwendt's sid_dis source.\n";
    $text .= "\nSID name to long filename conversion lifted from The Shark's SID2LFN.\n";

    $using  = "\nUses Audio::SID v" . Audio::SID->VERSION . ", ";
    $using .= "(C) 1999, 2004 LaLa <LaLa\@C64.org> and old versions of \n";
    $using .= "Perl (v5.8.9) and Tk (804.29_502).\n";
    $using .= "\nThe Windows executable has been created using Par Packager.\n";

    $text = $using . $text;

    $dialog = $window->DialogBox(
        -title => "About SIDedit v$VERSION",
        -buttons => ["OK"]);

    # Stupid dialog box doesn't provide default key-bindings.
    foreach ($dialog->children()) {
        if ($_->name() eq "bottom") {
            foreach $wid ($_->children()) {
                if ($wid->name() =~ /button/i) {
                    $wid->configure(-underline => 0);
                }
            }
        }
    }

    # This is a _VERY_ ugly hack:
    $dialog->bind("<o>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<O>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<Return>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<Escape>", sub {$dialog->{'selected_button'} = "OK";} );

    $dialog->add("Label", -image => 'SIDedit_icon')
        ->grid(-column => 1, -row => $row, -sticky => 'e');
    $dialog->add("Label", -text => "SIDedit v$VERSION", , -foreground => '#808000', -font => [@bigFont])
        ->grid(-column => 2, -row => $row, -sticky => 'w');
    $dialog->add("Label", -text => "(C) 1999-2004 by LaLa <LaLa\@C64.org>", -font => [@boldFont])
        ->grid(-column => 1, -row => ++$row, -columnspan => 2, -sticky => 'ew');
    $dialog->add("Label", -text => "Visit http://lala.c64.org for the official version", -font => [@boldFont])
        ->grid(-column => 1, -row => ++$row, -columnspan => 2, -sticky => 'ew');
    $dialog->add("Label", -text => "or https://github.com/wothke/SIDedit for this one.", -font => [@boldFont])
        ->grid(-column => 1, -row => ++$row, -columnspan => 2, -sticky => 'ew');
    $dialog->add("Label", -text => $text, -justify => 'left')
        ->grid(-column => 1, -row => ++$row, -columnspan => 2, -sticky => 'w');
    $dialog->add("Label", -text => "Thanks to the HVSC Crew for their help!", -font => [@boldFont])
        ->grid(-column => 1, -row => ++$row, -columnspan => 2, -sticky => 'ew');

    $dialog->protocol('WM_DELETE_WINDOW', undef);
    $dialog->Show();
}

# First param: ref. to current song number, second param: ref. to current bit setting,
# third param: ref. to bits array.
sub ChangeBit($$$) {
    my ($currsong, $currbit, $bitsref) = @_;

    if ($$currsong =~ /^32/) {
        $$bitsref[31] = $$currbit;
    }
    else {
        $$bitsref[$$currsong-1] = $$currbit;
    }
}

sub EditSpeed {
    my $dialog;
    my $listbox;
    my $maxsongs;
    my $row;
    my $song;
    my $speed;
    my $currsong;
    my $currbit;
    my @bits;
    my $answer;

    unless ($SIDfield{'songs'}) {
        ErrorBox("The number of songs is 0!");
        return;
    }

    $dialog = $window->DialogBox(
        -title => "SIDedit - Edit bits of the speed field",
        -buttons => ["OK", "Cancel"]);

    $dialog->add("Label", -text => "Enter the speed for each song below.\n('Vertical sync' means 50Hz PAL or 60Hz NTSC\nand '60 Hz' means 60 Hz or the CIA timer set in " . '$DC04/05.)')
            ->grid(-column => 0, -columnspan => 4, -row => 0, -sticky => 'ew');

    $dialog->add("Label", -text => "Song number:")
            ->grid(-column => 0, -row => 1, -sticky => 'e');

    # Stupid dialog box doesn't provide default key-bindings.
    foreach ($dialog->children()) {
        if ($_->name() eq "bottom") {
            foreach $wid ($_->children()) {
                if ($wid->name() =~ /button/i) {
                    $wid->configure(-underline => 0);
                }
            }
        }
    }

    # This is a _VERY_ ugly hack:
    $dialog->bind("<o>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<O>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<c>", sub {$dialog->{'selected_button'} = "Cancel";} );
    $dialog->bind("<C>", sub {$dialog->{'selected_button'} = "Cancel";} );

    # Remove this general binding.
    $dialog->bind("<Return>", '');

    $listbox = $dialog->add("Optionmenu",
        -variable => \$currsong,
        -command => sub {
            my ($selection) = @_;
            if ($selection =~ /^32/) {
                $selection = 32;
            }
            $currbit = $bits[$selection-1];
        });

    $maxsongs = ($SIDfield{'songs'} > 32) ? 32 : $SIDfield{'songs'};

    $speed = HexValue($SIDfield{'speed'});
    foreach $song (1 .. $maxsongs) {
        $bits[$song-1] = ($speed >> ($song-1)) & 0x1;

        if (($song == 32) and ($SIDfield{'songs'} > 32)) {
            $listbox->addOptions("$song - $SIDfield{'songs'}");
        }
        else {
            $listbox->addOptions($song);
        }
    }

    $currsong = 1;
    $currbit = $bits[$currsong-1];
    $listbox->setOption(1); # Sets default option.

    $listbox->grid(-column => 1, -row => 1, -sticky => 'w');

    $dialog->add("Radiobutton", @noBorder,
            -text => "Vertical sync", -underline => 0,
            -variable => \$currbit,
            -value => '0',
            -command => sub { ChangeBit(\$currsong, \$currbit, \@bits); } )
        ->grid(-column => 2, -row => 1, -sticky => 'ew');
    $dialog->add("Radiobutton", @noBorder,
            -text => "60 Hz", -underline => 0,
            -variable => \$currbit,
            -value => '1',
            -command => sub { ChangeBit(\$currsong, \$currbit, \@bits); } )
        ->grid(-column => 3, -row => 1, -sticky => 'ew');
    $row++;

    $dialog->bind("<v>", sub { $currbit = 0; ChangeBit(\$currsong, \$currbit, \@bits); } );
    $dialog->bind("<V>", sub { $currbit = 0; ChangeBit(\$currsong, \$currbit, \@bits); } );
    $dialog->bind("<KeyPress-6>", sub { $currbit = 1; ChangeBit(\$currsong, \$currbit, \@bits); } );

    $dialog->protocol('WM_DELETE_WINDOW', undef);
    $answer = $dialog->Show();

    if ($answer eq 'OK') {
        $speed = 0;
        foreach $song (1 .. $maxsongs) {
            $speed |= $bits[$song-1] << ($song-1);
        }
        $SIDfield{'speed'} = sprintf("0x%08X", $speed);
        $modified = 1;
    }
}

sub EditFlags {
    my $dialog;
    my $answer;
    my $frame;
    my $oldMUSPlayer = $MUSPlayer;
    my $oldPlaySID = $PlaySID;
    my $oldC64BASIC = $C64BASIC;
    my $oldVideo = $Video;
    my $oldSIDChip = $SIDChip;

    $dialog = $window->DialogBox(
        -title => "SIDedit - Edit the flags",
        -buttons => ["OK", "Cancel"]);

    # Stupid dialog box doesn't provide default key-bindings.
    foreach ($dialog->children()) {
        if ($_->name() eq "bottom") {
            foreach $wid ($_->children()) {
                if ($wid->name() =~ /button/i) {
                    $wid->configure(-underline => 0);
                }
            }
        }
    }

    # This is a _VERY_ ugly hack:
    $dialog->bind("<o>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<O>", sub {$dialog->{'selected_button'} = "OK";} );
    $dialog->bind("<c>", sub {$dialog->{'selected_button'} = "Cancel";} );
    $dialog->bind("<C>", sub {$dialog->{'selected_button'} = "Cancel";} );

    $frame = $dialog->add("LabFrame", -label => "Format of the binary data",
            -labelside => "acrosstop")
            ->pack(@topPack, @bothFill);
    $frame->Radiobutton(@noBorder,
            -text => "Has built-in player", -underline => 4,
            -variable => \$MUSPlayer,
            -value => 0)
        ->grid(-column => 0, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "Requires Compute's Sidplayer (MUS)", -underline => 19,
            -variable => \$MUSPlayer,
            -value => 1)
        ->grid(-column => 1, -row => 0, -sticky => 'w');

    $frame->Radiobutton(@noBorder,
            -text => "C64 compatible", -underline => 2,
            -variable => \$PlaySID,
            -value => 0,
            -state => $PlaySIDButtonState)
        ->grid(-column => 0, -row => 1, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "PlaySID specific", -underline => 1,
            -variable => \$PlaySID,
            -value => 1,
            -state => $PlaySIDButtonState)
        ->grid(-column => 1, -row => 1, -sticky => 'w');

    $frame->Checkbutton(@noBorder,
            -text => "C64 BASIC executable", -underline => 0,
            -variable => \$C64BASIC,
            -state => $C64BASICButtonState)
        ->grid(-column => 0, -row => 2, -sticky => 'w', -columnspan => 2);

    $frame = $dialog->add("LabFrame", -label => "Clock (video standard)",
            -labelside => "acrosstop")
            ->pack(@topPack, @bothFill);
    $frame->Radiobutton(@noBorder,
            -text => "Unknown", -underline => 0,
            -variable => \$Video,
            -value => 0)
        ->grid(-column => 0, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "PAL", -underline => 0,
            -variable => \$Video,
            -value => 1)
        ->grid(-column => 1, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "NTSC", -underline => 0,
            -variable => \$Video,
            -value => 2)
        ->grid(-column => 2, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "Either", -underline => 0,
            -variable => \$Video,
            -value => 3)
        ->grid(-column => 3, -row => 0, -sticky => 'w');

    $frame = $dialog->add("LabFrame", -label => "Intended for SID chip type",
            -labelside => "acrosstop")
            ->pack(@topPack, @bothFill);
    $frame->Radiobutton(@noBorder,
            -text => "Unknown", -underline => 2,
            -variable => \$SIDChip,
            -value => 0)
        ->grid(-column => 0, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "6581", -underline => 0,
            -variable => \$SIDChip,
            -value => 1)
        ->grid(-column => 1, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "8580", -underline => 0,
            -variable => \$SIDChip,
            -value => 2)
        ->grid(-column => 2, -row => 0, -sticky => 'w');
    $frame->Radiobutton(@noBorder,
            -text => "Either", -underline => 1,
            -variable => \$SIDChip,
            -value => 3)
        ->grid(-column => 3, -row => 0, -sticky => 'w');

    $dialog->bind("<b>", sub {$MUSPlayer = 0;} );
    $dialog->bind("<B>", sub {$MUSPlayer = 0;} );
    $dialog->bind("<s>", sub {$MUSPlayer = 1;} );
    $dialog->bind("<S>", sub {$MUSPlayer = 1;} );

    if ($PlaySIDButtonState eq 'normal') {
        $dialog->bind("<KeyPress-4>", sub {$PlaySID = 0;} );
        $dialog->bind("<l>", sub {$PlaySID = 1;} );
        $dialog->bind("<L>", sub {$PlaySID = 1;} );
    }

    if ($C64BASICButtonState eq 'normal') {
        $dialog->bind("<c>", sub {$C64BASIC = !$C64BASIC;} );
        $dialog->bind("<C>", sub {$C64BASIC = !$C64BASIC;} );
    }

    $dialog->bind("<u>", sub {$Video = 0;} );
    $dialog->bind("<U>", sub {$Video = 0;} );
    $dialog->bind("<p>", sub {$Video = 1;} );
    $dialog->bind("<P>", sub {$Video = 1;} );
    $dialog->bind("<n>", sub {$Video = 2;} );
    $dialog->bind("<N>", sub {$Video = 2;} );
    $dialog->bind("<e>", sub {$Video = 3;} );
    $dialog->bind("<E>", sub {$Video = 3;} );
    $dialog->bind("<k>", sub {$SIDChip = 0;} );
    $dialog->bind("<K>", sub {$SIDCHip = 0;} );
    $dialog->bind("<KeyPress-6>", sub {$SIDChip = 1;} );
    $dialog->bind("<KeyPress-8>", sub {$SIDChip = 2;} );
    $dialog->bind("<i>", sub {$SIDChip = 3;} );
    $dialog->bind("<I>", sub {$SIDCHip = 3;} );

    $dialog->protocol('WM_DELETE_WINDOW', undef);
    $answer = $dialog->Show();

    if ($answer eq 'OK') {
        $SIDfield{'flags'} = $MUSPlayer << $MUSPLAYER_OFFSET;

        if ($PlaySIDButtonState eq 'normal') {
            $SIDfield{'flags'} |= $PlaySID << $PLAYSID_OFFSET;
        }

        if ($C64BASICButtonState eq 'normal') {
            $SIDfield{'flags'} |= $C64BASIC << $C64BASIC_OFFSET;
        }

        $SIDfield{'flags'} |= $Video << $VIDEO_OFFSET;
        $SIDfield{'flags'} |= $SIDChip << $SIDCHIP_OFFSET;
        $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});

        # Clock is included in MD5 calculations.
        RecalcMD5();

        $modified = 1;
    }
    else {
        $MUSPlayer = $oldMUSPlayer;
        $PlaySID = $oldPlaySID;
        $C64BASIC = $oldC64BASIC;
        $Video = $oldVideo;
        $SIDChip = $oldSIDChip;
    }

    UpdateFlags();
}

# First param: path reference to executable, second param: previous window's widget,
# third param: window title.
sub ChooseExecutable($$$) {
    my ($path_ref, $prevWindow, $title) = @_;
    my $types;
    my $initialdir;
    my $initialfile;
    my $myPath;

    unless ($$path_ref) {
        $initialdir = cwd;
        $initialfile = '';
    }
    else {
        $initialdir = dirname($$path_ref);
        $initialfile = basename($$path_ref);
    }

    $prevWindow->grabRelease();

    if ($isWindows) {
        $types = [['Programs', ['.com', '.exe', '.bat']], ['All files', '*']];
    }
    else {
        $types = [['All files', '*']];
    }

    $myPath = $prevWindow->getOpenFile(
        -filetypes => $types,
        -initialdir => $initialdir,
        -initialfile => $initialfile,
        -title => 'SIDedit - ' . $title
    );

    if ($myPath) {
        $$path_ref = $myPath;
    }

    $prevWindow->grab();
    $prevWindow->focus();
    $prevWindow->raise();
}

sub ShowHelp {
    ShowTextBox($window, 'SIDedit - Quick tutorial', 'load', $SIDEDIT_POD);
}

# First param: parent window widget, second param: window title,
# third param: text to display OR 'load' if text should
# be loaded from a file, fourth param: optional filename if third param is 'load'.
sub ShowTextBox {
    my ($parent, $title, $text, $filename) = @_;
    my $dialog;
    my $textframe;
    my $textbox;
    my $textscroll;
    my $bottomframe;
    my $buttonPressed;
    my $textContent;
    my $fileContent;
    my $FILE;
    my $mindialog;
    my ($dialogMinWidth, $dialogMinHeight);
    my $podFile = 0;

    if ($text eq 'load') {
        if ($filename =~ /\.pod$/i) {
            $podFile = 1;
            $text = '';
        }
    }

    if (($text eq 'load') and !$podFile) {
        if (!open ($FILE, "< $filename")) {
            $textContent = "Couldn't open $filename for display!";
        }
        else {
            @fileContent = <$FILE>;
            $textContent = join('',@fileContent);
        }
    }
    else {
        $textContent = $text;
    }

    $dialog = $parent->Toplevel();
    $dialog->transient($parent);
    $dialog->withdraw();

    $dialog->title('SIDedit - ' . $title);

    $textframe = $dialog->Frame()
        ->pack(@topPack, @bothFill, @expand);

    if ($podFile) {
#        $textbox = $textframe->PodText(-file => $filename)
#                       ->pack(@leftPack, @expand, @bothFill);
    }
    else {
#        $textbox = $textframe->ROTextANSIColor(-height => 30, -width => 81,
        $textbox = $textframe->ROText(-height => 30, -width => 81,
            -wrap => 'word')
            ->pack(@leftPack, @expand, @bothFill);

        $textscroll = $textframe->Scrollbar(@sunken,
            -command => ['yview', $textbox])
            ->pack(@rightPack, @yFill);
        $textbox->configure(-yscrollcommand => ['set', $textscroll]);
    }

    # Mousewheel support - experimental.
    $textbox->bind("<4>", ['yview', 'scroll', +5, 'units']);
    $textbox->bind("<5>", ['yview', 'scroll', -5, 'units']);
    $textbox->bind('<MouseWheel>',
              [ sub { $_[0]->yview('scroll',-($_[1]/120)*3,'units') }, Tk::Ev("D")]);

    $textbox->insert('end', $textContent);

    $bottomframe = $dialog->Frame()
        ->pack(@bottomPack, @bothFill);
    $bottomframe->Button(-text => 'OK', -underline => 0, -width => 15,
            -command => sub { $buttonPressed = 1; } )
        ->pack(@leftPack, @expand, -pady => 5);

    if (($text ne 'load') and !$podFile) {
        $bottomframe->Button(-text => 'Save to file', -underline => 0, -width => 15,
                -command => sub {
                    my $tempfilename = $filename;

                    # Make default filename the one selected with .txt extension.
                    $tempfilename =~ s/(.*)\.\S+$/$1.txt/;

                    $tempfilename = $dialog->getSaveFile(
                        -filetypes => [['Text files', 'txt'],['All files', '*']],
                        -defaultextension => 'txt',
                        -initialdir => $directory,
                        -initialfile => $tempfilename,
                        -title => 'SIDedit - Save tool output to file'
                    );

                    unless ($tempfilename) {
                        $dialog->grab();
                        $dialog->focus();
                        $dialog->raise();
                        return;
                    }

                    unless (open(OUT, "> $tempfilename")) {
                        ErrorBox("Error saving to $tempfilename!");
                        $dialog->grab();
                        $dialog->focus();
                        $dialog->raise();
                        return;
                    }

                    print OUT $text;

                    close OUT;

                    $dialog->grab();
                    $dialog->focus();
                    $dialog->raise();
                } )
            ->pack(@leftPack, @expand, -pady => 5);

        $bottomframe->Button(-text => 'Copy to clipboard', -underline => 0, -width => 15,
                -command => sub {
                    if ($isWindows) {
                        Win32::Clipboard::Empty();
                        Win32::Clipboard::Set($text);
                    }
                    else {
                        $window->clipboardClear();
                        $window->clipboardAppend(-type => 'STRING', '--', $text);
                    }
                } )
            ->pack(@leftPack, @expand, -pady => 5);
    }

    # This is important - it allows minsize() to function later on.
    $dialog->update();

    $dialog->bind("<Return>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Control-o>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Alt-o>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Escape>" => sub { $buttonPressed = 1; });

    # So we can catch geometry when window is closed.
    $dialog->protocol('WM_DELETE_WINDOW', sub { $buttonPressed = 1; });

    $mindialog = $dialog->geometry();
    ($dialogMinWidth, $dialogMinHeight) = ($mindialog =~ /^(\d+)x(\d+)/);
    $dialog->minsize($dialogMinWidth, $dialogMinHeight);

    $dialog->geometry($ShowTextBoxGeometry) if ($ShowTextBoxGeometry);

    $dialog->deiconify();

    $dialog->grab();
    $dialog->raise();
    $dialog->focus();
    $textbox->focus();
    $dialog->waitVariable(\$buttonPressed);

    $ShowTextBoxGeometry = $dialog->geometry();
    $dialog->grabRelease();
    $dialog->withdraw();
}

# First param: the key that was pressed, second param: name of listbox widget,
# (MUST be a listbox!), third param: current index in the listbox.
sub HandleKeypress($$$) {
    my $keyPressed = shift;
    my $widget = shift; # Must be a listbox widget!
    my $index = shift;

    return unless ($widget);
    return unless (defined($widget->get(0)));

    if ($keypressOn) {
        # If a different key was pressed shortly after the first one,
        # we'll search for series of chars now stored in $keypresses.

        if ($keypresses !~ /^$keyPressed$/) {
            $keypresses .= $keyPressed;
        }
        $widget->afterCancel($keypressEventID);
    }
    else {
        $keypresses = $keyPressed;
        $keypressOn = 1;
    }

    # Restart timer.
    $keypressEventID = $widget->after($KEYPRESS_DELAY, sub { $keypressOn = 0; });

    $index = 0 unless (defined($index));

    if (($keypresses =~ /^\S$/) and
        ($widget->get($index) =~ /^\[?$keyPressed/i) and
        ($widget->get($index+1) =~ /^\[?$keyPressed/i)) {

        # If same key was pressed again, advance to next entry
        # that starts with the same letter.

        $widget->activate($index+1);
        $widget->see($index+1);
        $widget->selectionClear(0, 'end');
        $widget->selectionSet($index+1);
    }
    else {
        # Find first entry starting with series of chars.

        my @list = $widget->get(0, 'end');
        my $myindex = 0;

        foreach (@list) {
            if ($list[$myindex] =~ /^\[?$keypresses/i) {
                $widget->activate($myindex);
                $widget->see($myindex);
                $widget->selectionClear(0, 'end');
                $widget->selectionSet($myindex);
                last;
            }
            $myindex++;
        }
    }
}

##############################################################################
#
# Show data
#
##############################################################################

sub ShowSIDData {
    my $dialog;
    my $topframe;
    my $bottomframe;
    my $textframe;
    my $optionframe;
    my $moreoptionframe;
    my $entry;
    my $textbox;
    my $textscroll;
    my $loadAddress = sprintf('$%04X', $realLoadAddress);
    my $otherAddress = sprintf('$%04X', $realLoadAddress);
    my $myLoadRangeEnd = sprintf('$%04X', $loadRangeEnd);
    my $otherText = "Other (range is $loadAddress-$myLoadRangeEnd)";
    my $loadAddressText = "Load address ($loadAddress)";
    my $enableInitAddress = 'normal';
    my $enablePlayAddress = 'normal';
    my $geometry;
    my ($myMINWIDTH, $myMINHEIGHT);
    my $buttonPressed = 0;
    my $row = 0;
    my $trimRangeStart = $loadAddress;
    my $trimRangeEnd = $myLoadRangeEnd;
    my $TRbutton;
    my $TRSentry;
    my $TREentry;
    my $modifyStart = $loadAddress;
    my $MSentry;
    my $MBentry;
    my $ModButton;
    my $oldDisplayDataFrom;

    sub SetOtherAddress {
        if (HexValue($otherAddress) < $realLoadAddress) {
            $otherAddress = sprintf('$%04X', $realLoadAddress);
        }
        elsif (HexValue($otherAddress) > $loadRangeEnd) {
            $otherAddress = sprintf('$%04X', $loadRangeEnd);
        }
        else {
            $otherAddress = sprintf('$%04X', HexValue($otherAddress, 4));
        }

        if ($DisplayDataFrom eq 'other') {
            PopulateWithData($dialog, $textbox, $otherAddress, 0);
        }
    }

    if (HexValue($SIDfield{'initAddress'}) == 0) {
        $enableInitAddress = 'disabled';
        if ($DisplayDataFrom eq 'initAddress') {
            $oldDisplayDataFrom = 'initAddress';
            $DisplayDataFrom = 'loadAddress';
        }
    }

    if (HexValue($SIDfield{'playAddress'}) == 0) {
        $enablePlayAddress = 'disabled';
        if ($DisplayDataFrom eq 'playAddress') {
            $oldDisplayDataFrom = 'playAddress';
            $DisplayDataFrom = 'loadAddress';
        }
    }

    $dialog = $window->Toplevel();
    $dialog->transient($window);
    $dialog->withdraw();

    $dialog->title("SIDedit - SID data display");

    $textframe = $dialog->Frame()
        ->pack(@leftPack, @expand, @bothFill);
    $textbox = $textframe->ROText(-height => 20, -width => 44,
        -wrap => 'none', -selectbackground => 'lightyellow', -selectforeground => 'black')
        ->pack(@leftPack, @expand, @bothFill);
    $textscroll = $textframe->Scrollbar(@sunken,
        -command => ['yview', $textbox])
        ->pack(@rightPack, @yFill);
    $textbox->configure(-yscrollcommand => ['set', $textscroll]);

    # Mousewheel support - experimental.
    $textbox->bind("<4>", ['yview', 'scroll', +5, 'units']);
    $textbox->bind("<5>", ['yview', 'scroll', -5, 'units']);
    $textbox->bind('<MouseWheel>',
              [ sub { $_[0]->yview('scroll',-($_[1]/120)*3,'units') }, Tk::Ev("D")]);

    $topframe = $dialog->Frame()
        ->pack(@leftPack, @bothFill, -padx => 5);
    $optionframe = $topframe->Frame()
        ->pack(@topPack);

    $moreoptionframe = $optionframe->LabFrame(-label => 'Data display options',
        -labelside => "acrosstop")
        ->grid(-column => 0, -row => 0, -sticky => 'ew');

    $moreoptionframe->Label(-text => 'Format:')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "Hex dump",
            -variable => \$DisplayDataAs,
            -command => sub { PopulateWithData($dialog, $textbox, $otherAddress, 1); },
            -value => 'hex')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "Assembly",
            -variable => \$DisplayDataAs,
            -command => sub { PopulateWithData($dialog, $textbox, $otherAddress, 1); },
            -value => 'assembly')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "Assembly with\nillegal instructions",
            -justify => 'left',
            -variable => \$DisplayDataAs,
            -command => sub { PopulateWithData($dialog, $textbox, $otherAddress, 1); },
            -value => 'assembly_illegal')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');

    $moreoptionframe->Label(-text => 'Starting from:')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -textvariable => \$loadAddressText,
            -variable => \$DisplayDataFrom,
            -command => sub { $oldDisplayDataFrom = ''; PopulateWithData($dialog, $textbox, $otherAddress, 0); },
            -value => 'loadAddress')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "initAddress ($SIDfield{initAddress})",
            -state => $enableInitAddress,
            -variable => \$DisplayDataFrom,
            -command => sub { $oldDisplayDataFrom = ''; PopulateWithData($dialog, $textbox, $otherAddress, 0); },
            -value => 'initAddress')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "playAddress ($SIDfield{playAddress})",
            -state => $enablePlayAddress,
            -variable => \$DisplayDataFrom,
            -command => sub { $oldDisplayDataFrom = ''; PopulateWithData($dialog, $textbox, $otherAddress, 0); },
            -value => 'playAddress')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -textvariable => \$otherText,
            -variable => \$DisplayDataFrom,
            -command => sub { $oldDisplayDataFrom = ''; $entry->focus(); PopulateWithData($dialog, $textbox, $otherAddress, 0); },
            -value => 'other')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');

    $entry = $moreoptionframe->Entry(
             -textvariable => \$otherAddress,
             -width => 6)
        ->grid(-column => 0, -row => $row++, -sticky => 'w');

    $entry->bind("<Return>", sub { SetOtherAddress(); } );
    $entry->bind("<FocusOut>", sub { SetOtherAddress(); } );

    $row = 0;
    $moreoptionframe = $optionframe->LabFrame(-label => 'Save data',
        -labelside => "acrosstop")
        ->grid(-column => 0, -row => 1, -sticky => 'ew');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "as binary",
            -variable => \$SaveDataAs,
            -value => 'binary')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "as 64 KB memory image",
            -variable => \$SaveDataAs,
            -value => 'image')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Radiobutton(@noBorder,
            -text => "as displayed (ASCII text)",
            -variable => \$SaveDataAs,
            -value => 'ascii')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $moreoptionframe->Button(-text => 'Save data to file', -underline => 0,
            -command => sub { SaveSIDData($textbox, $dialog); } )
        ->grid(-column => 0, -row => $row++);

    $row = 0;
    $moreoptionframe = $optionframe->LabFrame(-label => 'Trim/pad data',
        -labelside => "acrosstop")
        ->grid(-column => 0, -row => 2, -sticky => 'ew');
    $moreoptionframe->Label(
            -text => "Trim or pad the SID data\nto the new range below.",
            -justify => 'left')
        ->grid(-column => 0, -row => $row++, -columnspan => 4, -sticky => 'w');
    $moreoptionframe->Label(
            -text => "New range:")
        ->grid(-column => 0, -row => $row, -sticky => 'w');

    $TRSentry = $moreoptionframe->Entry(
             -textvariable => \$trimRangeStart,
             -width => 6)
        ->grid(-column => 1, -row => $row, -sticky => 'w');

    $moreoptionframe->Label(
             -text => ' - ')
        ->grid(-column => 2, -row => $row, -sticky => 'w');

    $TREentry = $moreoptionframe->Entry(
             -textvariable => \$trimRangeEnd,
             -width => 6)
        ->grid(-column => 3, -row => $row++, -sticky => 'w');

    $TRbutton = $moreoptionframe->Button(-text => 'Trim/pad data', -underline => 0,
            -command => sub {
                TrimData(\$trimRangeStart, \$trimRangeEnd, $dialog, \$loadAddress, \$otherAddress, \$myLoadRangeEnd, \$otherText, \$loadAddressText, $textbox, $entry);
            })
        ->grid(-column => 0, -row => $row++, -columnspan => 4);

    $TRSentry->bind("<Return>", sub {$trimRangeStart = sprintf('$%04X', HexValue($trimRangeStart, 4)); $TREentry->focus(); } );
    $TRSentry->bind("<FocusOut>", sub {$trimRangeStart = sprintf('$%04X', HexValue($trimRangeStart, 4)); } );

    $TREentry->bind("<Return>", sub {$trimRangeEnd = sprintf('$%04X', HexValue($trimRangeEnd, 4)); $TRbutton->focus(); } );
    $TREentry->bind("<FocusOut>", sub {$trimRangeEnd = sprintf('$%04X', HexValue($trimRangeEnd, 4)); } );

    $row = 0;
    $moreoptionframe = $optionframe->LabFrame(-label => 'Modify data',
        -labelside => "acrosstop")
        ->grid(-column => 0, -row => 3, -sticky => 'ew');
    $moreoptionframe->Label(
            -text => "Modify the byte(s) starting\nat the given address.",
            -justify => 'left')
        ->grid(-column => 0, -row => $row++, -columnspan => 2, -sticky => 'w');
    $moreoptionframe->Label(
            -text => "At address:")
        ->grid(-column => 0, -row => $row, -sticky => 'e');

    $MSentry = $moreoptionframe->Entry(
             -textvariable => \$modifyStart,
             -width => 6)
        ->grid(-column => 1, -row => $row++, -sticky => 'w');

    $moreoptionframe->Label(
             -text => 'change bytes to:')
        ->grid(-column => 0, -row => $row, -sticky => 'e');

    $MBentry = $moreoptionframe->Entry(
             -textvariable => \$modifyBytes,
             -width => 10)
        ->grid(-column => 1, -row => $row++, -sticky => 'w');

    $ModButton = $moreoptionframe->Button(-text => 'Modify bytes', -underline => 0,
            -command => sub {
                ModifyData(\$modifyStart, \$modifyBytes, \$otherAddress, $dialog, $textbox, $entry);
            })
        ->grid(-column => 0, -columnspan => 2, -row => $row++, -sticky => 'ns');

    $MSentry->bind("<Return>", sub {$modifyStart = sprintf('$%04X', HexValue($modifyStart, 4)); $MBentry->focus(); } );
    $MSentry->bind("<FocusOut>", sub {$modifyStart = sprintf('$%04X', HexValue($modifyStart, 4)); } );

    $MBentry->bind("<Return>", sub {$ModButton->focus(); } );

    $bottomframe = $topframe->Frame()
        ->pack(@bottomPack, @xFill);
    $bottomframe->Button(-text => 'OK', -underline => 0,
            -command => sub { $buttonPressed = 1; } )
        ->pack(@bottomPack, @expand, @xFill, -pady => 2);

    PopulateWithData($dialog, $textbox, $otherAddress, 1);

    # This is important - it allows minsize() to function later on.
    $dialog->update();

#    $dialog->bind("<Return>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Escape>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Control-o>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Alt-o>" => sub { $buttonPressed = 1; });
    $dialog->bind("<Control-s>" => sub { SaveSIDData($textbox, $dialog); } );
    $dialog->bind("<Alt-s>" => sub { SaveSIDData($textbox, $dialog); } );
    $dialog->bind("<Control-t>" => sub {
        TrimData(\$trimRangeStart, \$trimRangeEnd, $dialog, \$loadAddress, \$otherAddress, \$myLoadRangeEnd, \$otherText, \$loadAddressText, $textbox, $entry);
    });
    $dialog->bind("<Alt-t>" => sub {
        TrimData(\$trimRangeStart, \$trimRangeEnd, $dialog, \$loadAddress, \$otherAddress, \$myLoadRangeEnd, \$otherText, \$loadAddressText, $textbox, $entry);
    });
    $dialog->bind("<Control-m>" => sub {
        ModifyData(\$modifyStart, \$modifyBytes, \$otherAddress, $dialog, $textbox, $entry);
    });
    $dialog->bind("<Alt-m>" => sub {
        ModifyData(\$modifyStart, \$modifyBytes, \$otherAddress, $dialog, $textbox, $entry);
    });

    # So we can catch geometry when window is closed.
    $dialog->protocol('WM_DELETE_WINDOW', sub { $buttonPressed = 1; });

    $geometry = $dialog->geometry();
    ($myMINWIDTH, $myMINHEIGHT) = ($geometry =~ /^(\d+)x(\d+)/);
    $dialog->minsize($myMINWIDTH, $myMINHEIGHT);
    $dialog->geometry($ShowSIDDataGeometry) if ($ShowSIDDataGeometry);

    $dialog->deiconify();

    $dialog->grab();
    $textbox->focus();
    $dialog->waitVariable(\$buttonPressed);

    $ShowSIDDataGeometry = $dialog->geometry();

    $dialog->grabRelease();
    $dialog->withdraw();

    # Restore old setting.
    if ($oldDisplayDataFrom) {
        $DisplayDataFrom = $oldDisplayDataFrom;
    }
}

# Lots of params specific to the trim data feature!
sub TrimData ($$$$$$$$$$) {
    my ($trimRangeStart, $trimRangeEnd, $dialog, $loadAddress, $otherAddress, $myLoadRangeEnd, $otherText, $loadAddressText, $textbox, $entry) = @_;

    my $start = HexValue($$trimRangeStart,4);
    my $end = HexValue($$trimRangeEnd,4);
    my $startfrom = 2;

    $startfrom = 0 if (HexValue($SIDfield{'loadAddress'},4) != 0);

    if (($start >= $loadRangeEnd) or
        ($end <= $realLoadAddress) or
        ($start >= $end)) {

        ErrorBox("Error: trim/pad range is invalid!");
        $dialog->grab();
        $dialog->focus();
        $dialog->raise();
        return;
    }

    unless (YesNoBox("Are you sure you want to alter the data to have a new load range of\n$$trimRangeStart - $$trimRangeEnd?")) {
        $dialog->grab();
        $dialog->focus();
        $dialog->raise();
        return;
    }

    # This MUST be done first!
    if ($end > $loadRangeEnd) {
        my $newdata;

        # Pad after.
        for (1 .. ($end - $loadRangeEnd)) {
            $newdata .=  pack('C', 0);
        }

        $SIDfield{'data'} .= $newdata;
    }
    else {
        # Crop end.
        $SIDfield{'data'} = substr($SIDfield{'data'},0,length($SIDfield{'data'}) - ($loadRangeEnd - $end));
    }

    if ($start ne $realLoadAddress) {
        if ($start < $realLoadAddress) {
            my $newdata;

            # Pad before.
            for (1 .. ($realLoadAddress - $start)) {
                $newdata .= pack('C', 0);
            }

            $SIDfield{'data'} = $newdata . substr($SIDfield{'data'},$startfrom);
        }
        else {
            # Crop start.
            $SIDfield{'data'} = substr($SIDfield{'data'}, $startfrom + $start - $realLoadAddress);
        }

        if (HexValue($SIDfield{'loadAddress'},4) == 0) {
            # Replace first two bytes with new load address.
            $SIDfield{'data'} = pack('C', $start & 0xFF) . pack('C', ($start >> 8) & 0xFF) .$SIDfield{'data'};
        }
        else {
            $SIDfield{'loadAddress'} = sprintf('$%04X', $start);
            $mySID->set('loadAddress' => $start);
        }
    }

    $mySID->set('data' => $SIDfield{'data'});

    # Since old init/play addresses may be out of range:
    $DisplayDataFrom = 'loadAddress';

    # Update fields displayed in this window.
    PopulateSIDfields();
    $$loadAddress = sprintf('$%04X', $realLoadAddress);
    $$otherAddress = sprintf('$%04X', $realLoadAddress);
    $$myLoadRangeEnd = sprintf('$%04X', $loadRangeEnd);
    $$otherText = "Other (range is $$loadAddress-$$myLoadRangeEnd)";
    $$loadAddressText = "Load address ($$loadAddress)";

    PopulateWithData($dialog, $textbox, $$otherAddress, 1);
    $dialog->update();
    $dialog->grab();
    $dialog->focus();
    $dialog->raise();
    $modified = 1;
};

# Lots of params specific to the modify data feature!
sub ModifyData {
    my ($modifyStart, $modifyBytes, $otherAddress, $dialog, $textbox, $entry) = @_;
    my $dataOffset;
    my @bytes;
    my $i;
    my $newdata;
    my $questionText;
    my $byteList;

    my $start = HexValue($$modifyStart,4);

    if (($start > $loadRangeEnd) or ($start < $realLoadAddress)) {

        ErrorBox("Error: modification address is outside the load range!");
        $dialog->grab();
        $dialog->focus();
        $dialog->raise();
        return;
    }

    $dataOffset = $start - $realLoadAddress;

    if (HexValue($SIDfield{'loadAddress'},4) == 0) {
        $dataOffset += 2;
    }

    @bytes = split(/[\s,;]+/, $$modifyBytes);

    if ($#bytes > ($loadRangeEnd - $start)) {
        $questionText = "Too many bytes specified, byte list has been truncated.\n";
        splice(@bytes, ($loadRangeEnd - $start) + 1);
    }

    for ($i = 0; $i <= $#bytes; $i++) {
        $newdata .= pack('C', HexValue($bytes[$i], 2));
        $byteList .= "$bytes[$i] ";
    }

    unless (YesNoBox($questionText . "Are you sure you want to change the data\nstarting at $$modifyStart to '$byteList'?")) {
        $dialog->grab();
        $dialog->focus();
        $dialog->raise();
        return;
    }

    substr($SIDfield{'data'}, $dataOffset, length($newdata), $newdata);

    $mySID->set('data' => $SIDfield{'data'});

    PopulateWithData($dialog, $textbox, $$otherAddress, 1);
    $dialog->update();
    $dialog->grab();
    $dialog->focus();
    $dialog->raise();
    $modified = 1;
};

# First param: name of textbox widget, second param: name of dialog window contaning the textbox.
sub SaveSIDData($$) {
    my ($textbox, $dialog) = @_;
    my $tempfilename;
    my $newExtension;
    my $extensionName;

    if ($SaveDataAs eq 'binary') {
        $newExtension = '.prg';
        $extensionName = 'C64 binaries';
    }
    elsif ($SaveDataAs eq 'image')  {
        $newExtension = '.img';
        $extensionName = 'C64 memory image files';
    }
    else {
        $newExtension = '.txt';
        $extensionName = 'ASCII text files';
    }

    $tempfilename = "$directory" . $separator . "$filename";
    $tempfilename = "$drive$tempfilename" if ($isWindows);

    if ($filename =~ /\.sid$/) {
        $tempfilename =~ s/\.sid$/$newExtension/;
    }
    else {
        $tempfilename .= $newExtension;
    }

    $tempfilename = $dialog->getSaveFile(
        -filetypes => [[$extensionName, $newExtension], ['All files', '*']],
        -defaultextension => $newExtension,
        -initialdir => dirname($tempfilename),
        -initialfile => basename($tempfilename),
        -title => 'SIDedit - Save SID data to file'
    );

    unless ($tempfilename) {
        $dialog->grab();
        $dialog->focus();
        $dialog->raise();
        return;
    }

    unless (open(OUT, "> $tempfilename")) {
        ErrorBox("Error saving to $tempfilename!");
        $dialog->grab();
        $dialog->focus();
        $dialog->raise();
        return;
    }

    $dialog->grab();
    $dialog->focus();
    $dialog->raise();

    binmode OUT;

    if ($SaveDataAs eq 'binary') {
        print OUT $SIDfield{'data'};
    }
    elsif ($SaveDataAs eq 'image') {
        # Prepend data with zeroes.
        print OUT pack('C', 0) x $realLoadAddress;

        if ((length($SIDfield{'data'}) > 2) and (HexValue($SIDfield{'loadAddress'}) == 0)) {
            # Don't save load address - this is a memory image.
            print OUT substr($SIDfield{'data'},2);
        }
        else {
            print OUT $SIDfield{'data'};
        }

        # Append zeroes to data.
        print OUT pack('C', 0) x (0xFFFF - $loadRangeEnd);
    }
    else {
        print OUT $textbox->get('1.0', 'end');
    }

    close OUT;
}

# First param: name of textbox widget, second param: ref. to textbox widget,
# third param: value of 'other' address, fourth param: name of 'other' entry widget,
# fifth param: jump to current top address?
sub PopulateWithData($$$$) {
    my ($datawindow, $textbox, $otherAddress, $jump) = @_;
    my $address;
    my $dataindex = 0;
    my $waitwindow;
    my $waitByteCutoff = $ShowColors ? 5000 : 10000;

    if ($DisplayDataFrom eq 'loadAddress') {
        $address = $realLoadAddress;
    }
    elsif ($DisplayDataFrom eq 'other') {
        $address = HexValue($otherAddress);
    }
    elsif ($DisplayDataFrom eq 'initAddress') {
        if (HexValue($SIDfield{'initAddress'}) == 0) {
            $address = $realLoadAddress;
        }
        else {
            $address = HexValue($SIDfield{'initAddress'});
        }
    }
    elsif ($DisplayDataFrom eq 'playAddress') {
        $address = HexValue($SIDfield{'playAddress'});
    }
    else {
        return;
    }

    return if (length($SIDfield{'data'}) < 1);

    if (length($SIDfield{'data'}) > $waitByteCutoff) {

        $waitwindow = $window->WaitBox(-title => 'SIDedit - Please wait!',
           -txt1 => 'Please wait!',
           -txt2 => 'SIDedit is busy.');

        $waitwindow->resizable(0,0);

        $waitwindow->Show();
    }

    if (HexValue($SIDfield{'loadAddress'}) == 0) {
        return if (length($SIDfield{'data'}) < 3);

        $dataindex += 2;
    }

    if ($textbox->get('1.0')) {
        my $lastline;
        my $topline;
        my $junk;

        if ($jump) {
            # Let's find out  which line is the topmost visible line.
            ($lastline, $junk) = split(/\./, $textbox->index('end'));
            ($topline, $junk) = $textbox->yview();
            $topline = int($lastline * $topline + 1);

            $JumpToMark = $textbox->markNext("$topline.0");
        }
        else {
            $JumpToMark = '';
        }

        # Clear out textbox contents.
        $textbox->markUnset($textbox->markNames());
        $textbox->tagDelete($textbox->tagNames());
        $textbox->delete('1.0', 'end');
    }

    if (($address < $realLoadAddress) or ($address > $loadRangeEnd)) {
        $textbox->insert('end', "ERROR: Address is out of range!\n");
        return;
    }
    else {
        $dataindex += ($address - $realLoadAddress);
    }

    if ($DisplayDataAs eq 'hex') {
        PopulateWithHexDump($address, $dataindex, $textbox);
    }
    elsif ($DisplayDataAs eq 'assembly') {
        PopulateWithAssembly($address, $dataindex, $textbox, 0);
    }
    elsif ($DisplayDataAs eq 'assembly_illegal') {
        PopulateWithAssembly($address, $dataindex, $textbox, 1);
    }

    if ($waitwindow) {
        $waitwindow->unShow();
        $window->configure(-cursor => '');
    }
}

# First param: starting address, second param: starting index into data,
# third param: name of textbox widget to populate with output.
sub PopulateWithHexDump($$$) {
    my ($address, $dataindex, $textbox) = @_;
    my $line = '';
    my $chars = '';
    my $i = 0;
    my $byte;
    my $startAddress;
    my $lineNo = 1;
    my $markHex;
    my @marks;
    my $hexAddress;

    if ($ShowColors) {
        # Set up coloring scheme.
        $textbox->tagConfigure('addrColor', -foreground => 'darkred');
        $textbox->tagConfigure('hexColor',  -foreground => 'darkblue');
        $textbox->tagConfigure('dataColor', -foreground => 'darkgreen');
    }

    $startAddress = $address - ($address % 8);

    while ($startAddress <= $loadRangeEnd) {
        $hexAddress = sprintf("%04X", $startAddress);

        $line = '$' . "$hexAddress";

        # Set a marker here so we can jump to it.
        $markHex = "mark$hexAddress";
        push(@marks, $markHex);
        $textbox->markSet($markHex, "$lineNo.0");
        $textbox->markGravity($markHex, 'left');

        $i = 0;
        $chars = '';
        while ($i < 8) {
            if (($startAddress >= $address) and ($startAddress <= $loadRangeEnd)) {
                $byte = unpack("C", substr($SIDfield{'data'}, $dataindex, 1));
                $line .= sprintf(' %02X', $byte);

                if (($byte > 0x80) and (chr($byte-0x80) =~ /^[ \w]$/)) {
                    # Convert C64 uppercase to ASCII uppercase.
                    $chars .= chr($byte-0x80);
                }
                elsif (chr($byte) =~ /^[ \w]$/) {
                    $chars .= chr($byte);
                }
                else {
                    $chars .= '.';
                }
            }
            else {
                $line .= '   ';
                $chars .= ' ';
            }

            $line .= ' |' if ($i == 3);
            $i++;
            if ($startAddress >= $address) {
                $dataindex++;
            }
            $startAddress++;
        }

        $textbox->insert('end', "$line | $chars\n");

        if ($ShowColors) {
            # Add colors.
            $textbox->tagAdd('addrColor', "$lineNo.0", "$lineNo.5");
            $textbox->tagAdd('hexColor',  "$lineNo.6", "$lineNo.17");
            $textbox->tagAdd('hexColor',  "$lineNo.20", "$lineNo.32");
            $textbox->tagAdd('dataColor', "$lineNo.34", "$lineNo.42");
        }

        $lineNo++;
    }


    # Display given line on top.
    if (grep(/$JumpToMark/,@marks)) {
        # Use 'yview' instead of 'see' to show mark on top, not in middle.
        $textbox->yview($JumpToMark);
    }
    else {
        # Try to find the closest mark if this one doesn't exist.
        my $index = 0;

        while (($marks[$index] lt $JumpToMark) and ($index <= $#marks)) {
            $index++;
        }

        if ($index > 0) {
            $index--;
        }

        $textbox->yview($marks[$index]);
    }
}

#
# Instruction definitions lifted from Michael Schwendt's sid_dis source.
#

my @instrNameList =
(
# XXX replaced operation names with the ones I am used to
"BRK", "ORA", "JAM", "SLO", "NOP", "ORA", "ASL", "SLO", "PHP", "ORA", "ASL", "ANC", "NOP", "ORA", "ASL", "SLO",
"BPL", "ORA", "JAM", "SLO", "NOP", "ORA", "ASL", "SLO", "CLC", "ORA", "NOP", "SLO", "NOP", "ORA", "ASL", "SLO",
"JSR", "AND", "JAM", "RLA", "BIT", "AND", "ROL", "RLA", "PLP", "AND", "ROL", "ANC", "BIT", "AND", "ROL", "RLA",
"BMI", "AND", "JAM", "RLA", "NOP", "AND", "ROL", "RLA", "SEC", "AND", "NOP", "RLA", "NOP", "AND", "ROL", "RLA",
"RTI", "EOR", "JAM", "SRE", "NOP", "EOR", "LSR", "SRE", "PHA", "EOR", "LSR", "ALR", "JMP", "EOR", "LSR", "SRE",
"BVC", "EOR", "JAM", "SRE", "NOP", "EOR", "LSR", "SRE", "CLI", "EOR", "NOP", "SRE", "NOP", "EOR", "LSR", "SRE",
"RTS", "ADC", "JAM", "RRA", "NOP", "ADC", "ROR", "RRA", "PLA", "ADC", "ROR", "ARR", "JMP", "ADC", "ROR", "RRA",
"BVS", "ADC", "JAM", "RRA", "NOP", "ADC", "ROR", "RRA", "SEI", "ADC", "NOP", "RRA", "NOP", "ADC", "ROR", "RRA",
"NOP", "STA", "NOP", "SAX", "STY", "STA", "STX", "SAX", "DEY", "NOP", "TXA", "ANE", "STY", "STA", "STX", "SAX",
"BCC", "STA", "JAM", "SHA", "STY", "STA", "STX", "SAX", "TYA", "STA", "TXS", "SHS", "SHY", "STA", "SHX", "SHA",
"LDY", "LDA", "LDX", "LAX", "LDY", "LDA", "LDX", "LAX", "TAY", "LDA", "TAX", "LXA", "LDY", "LDA", "LDX", "LAX",
"BCS", "LDA", "JAM", "LAX", "LDY", "LDA", "LDX", "LAX", "CLV", "LDA", "TSX", "LAE", "LDY", "LDA", "LDX", "LAX",
"CPY", "CMP", "NOP", "DCP", "CPY", "CMP", "DEC", "DCP", "INY", "CMP", "DEX", "SBX", "CPY", "CMP", "DEC", "DCP",
"BNE", "CMP", "JAM", "DCP", "NOP", "CMP", "DEC", "DCP", "CLD", "CMP", "NOP", "DCP", "NOP", "CMP", "DEC", "DCP",
"CPX", "SBC", "NOP", "ISB", "CPX", "SBC", "INC", "ISB", "INX", "SBC", "NOP", "SBC", "CPX", "SBC", "INC", "ISB",
"BEQ", "SBC", "JAM", "ISB", "NOP", "SBC", "INC", "ISB", "SED", "SBC", "NOP", "ISB", "NOP", "SBC", "INC", "ISB"

#"BRK", "ORA", "ILL_TILT", "ASLORA", "ILL_2NOP", "ORA", "ASL", "ASLORA",
#"PHP", "ORA", "ASL",      "ILL_0B", "ILL_3NOP", "ORA", "ASL", "ASLORA",
#"BPL", "ORA", "ILL_TILT", "ASLORA", "ILL_2NOP", "ORA", "ASL", "ASLORA",
#"CLC", "ORA", "ILL_1NOP", "ASLORA", "ILL_3NOP", "ORA", "ASL", "ASLORA",
#"JSR", "AND", "ILL_TILT", "ROLAND", "BIT",      "AND", "ROL", "ROLAND",
#"PLP", "AND", "ROL",      "ILL_0B", "BIT",      "AND", "ROL", "ROLAND",
#"BMI", "AND", "ILL_TILT", "ROLAND", "ILL_2NOP", "AND", "ROL", "ROLAND",
#"SEC", "AND", "ILL_1NOP", "ROLAND", "ILL_3NOP", "AND", "ROL", "ROLAND",
# 0x40
#"RTI", "EOR", "ILL_TILT", "LSREOR", "ILL_2NOP", "EOR", "LSR", "LSREOR",
#"PHA", "EOR", "LSR",      "ILL_4B", "JMP",      "EOR", "LSR", "LSREOR",
#"BVC", "EOR", "ILL_TILT", "LSREOR", "ILL_2NOP", "EOR", "LSR", "LSREOR",
#"CLI", "EOR", "ILL_1NOP", "LSREOR", "ILL_3NOP", "EOR", "LSR", "LSREOR",
#"RTS", "ADC", "ILL_TILT", "RORADC", "ILL_2NOP", "ADC", "ROR", "RORADC",
#"PLA", "ADC", "ROR",      "ILL_6B", "JMP",      "ADC", "ROR", "RORADC",
#"BVS", "ADC", "ILL_TILT", "RORADC", "ILL_2NOP", "ADC", "ROR", "RORADC",
#"SEI", "ADC", "ILL_1NOP", "RORADC", "ILL_3NOP", "ADC", "ROR", "RORADC",
# 0x80
#"ILL_2NOP", "STA",      "ILL_2NOP", "ILL_83",   "STY",    "STA", "STX", "ILL_87",
#"DEY",      "ILL_2NOP", "TXA",      "ILL_8B",   "STY",    "STA", "STX", "ILL_8F",
#"BCC",      "STA",      "ILL_TILT", "ILL_93",   "STY",    "STA", "STX", "ILL_97",
#"TYA",      "STA",      "TXS",      "ILL_9B",   "ILL_9C", "STA", "ILL_9E", "ILL_9F",
#"LDY",      "LDA",      "LDX",      "ILL_A3",   "LDY",    "LDA", "LDX", "ILL_A7",
#"TAY",      "LDA",      "TAX",      "ILL_1NOP", "LDY",    "LDA", "LDX", "ILL_AF",
#"BCS",      "LDA",      "ILL_TILT", "ILL_B3",   "LDY",    "LDA", "LDX", "ILL_B7",
#"CLV",      "LDA",      "TSX",      "ILL_BB",   "LDY",    "LDA", "LDX", "ILL_BF",
# 0xC0
#"CPY", "CMP", "ILL_2NOP", "DECCMP", "CPY",      "CMP", "DEC", "DECCMP",
#"INY", "CMP", "DEX",      "ILL_CB", "CPY",      "CMP", "DEC", "DECCMP",
#"BNE", "CMP", "ILL_TILT", "DECCMP", "ILL_2NOP", "CMP", "DEC", "DECCMP",
#"CLD", "CMP", "ILL_1NOP", "DECCMP", "ILL_3NOP", "CMP", "DEC", "DECCMP",
#"CPX", "SBC", "ILL_2NOP", "INCSBC", "CPX",      "SBC", "INC", "INCSBC",
#"INX", "SBC",  "NOP",     "ILL_EB", "CPX",      "SBC", "INC", "INCSBC",
#"BEQ", "SBC", "ILL_TILT", "INCSBC", "ILL_2NOP", "SBC", "INC", "INCSBC",
#"SED", "SBC", "ILL_1NOP", "INCSBC", "ILL_3NOP", "SBC", "INC", "INCSBC"
);

my @instrFlagList =
(
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
# 0x40
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
# 0x80
"ILL", "DEF", "ILL", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "ILL", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "ILL", "DEF", "ILL", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
# 0xC0
"DEF", "DEF", "ILL", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "DEF", "ILL", "DEF", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL",
"DEF", "DEF", "ILL", "ILL", "ILL", "DEF", "DEF", "ILL"
);

my @instrTypeList =
(
# &BRK_, &ORA_indx, &ILL_TILT, &ASLORA_indx, &ILL_2NOP, &ORA_zp, &ASL_zp, &ASLORA_zp,
"NONE", "INDX", "NONE", "INDX", "NONE", "ZP", "ZP", "ZP",
# &PHP_, &ORA_imm, &ASL_AC, &ILL_0B, &ILL_3NOP, &ORA_abs, &ASL_abs, &ASLORA_abs,
"NONE", "IMM", "NONE", "IMM", "NONE", "ABS", "ABS", "ABS",
# &BPL_, &ORA_indy, &ILL_TILT, &ASLORA_indy, &ILL_2NOP, &ORA_zpx, &ASL_zpx, &ASLORA_zpx,
"BR", "INDY", "NONE", "INDY", "NONE", "ZPX", "ZPX", "ZPX",
# &CLC_, &ORA_absy, &ILL_1NOP, &ASLORA_absy, &ILL_3NOP, &ORA_absx, &ASL_absx, &ASLORA_absx,
"NONE", "ABSY", "NONE", "ABSY", "NONE", "ABSX", "ABSX", "ABSX",
# &JSR_, &AND_indx, &ILL_TILT, &ROLAND_indx, &BIT_zp, &AND_zp, &ROL_zp, &ROLAND_zp,
"ABS", "INDX", "NONE", "INDX", "ZP", "ZP", "ZP", "ZP",
# &PLP_, &AND_imm, &ROL_AC, &ILL_0B, &BIT_abs, &AND_abs, &ROL_abs, &ROLAND_abs,
"NONE", "IMM", "NONE", "IMM", "ABS", "ABS", "ABS", "ABS",
# &BMI_, &AND_indy, &ILL_TILT, &ROLAND_indy, &ILL_2NOP, &AND_zpx, &ROL_zpx, &ROLAND_zpx,
"BR", "INDY", "NONE", "INDY", "NONE", "ZPX", "ZPX", "ZPX",
# &SEC_, &AND_absy, &ILL_1NOP, &ROLAND_absy, &ILL_3NOP, &AND_absx, &ROL_absx, &ROLAND_absx,
"NONE", "ABSY", "NONE", "ABSY", "NONE", "ABSX", "ABSX", "ABSX",
# 0x40
# &RTI_, &EOR_indx, &ILL_TILT, &LSREOR_indx, &ILL_2NOP, &EOR_zp, &LSR_zp, &LSREOR_zp,
"NONE", "INDX", "NONE", "INDX", "NONE", "ZP", "ZP", "ZP",
# &PHA_, &EOR_imm, &LSR_AC, &ILL_4B, &JMP_, &EOR_abs, &LSR_abs, &LSREOR_abs,
"NONE", "IMM", "NONE", "IMM", "ABS", "ABS", "ABS", "ABS",
# &BVC_, &EOR_indy, &ILL_TILT, &LSREOR_indy, &ILL_2NOP, &EOR_zpx, &LSR_zpx, &LSREOR_zpx,
"BR", "INDY", "NONE", "INDY", "NONE", "ZPX", "ZPX", "ZPX",
# &CLI_, &EOR_absy, &ILL_1NOP, &LSREOR_absy, &ILL_3NOP, &EOR_absx, &LSR_absx, &LSREOR_absx,
"NONE", "ABSY", "NONE", "ABSY", "NONE", "ABSX", "ABSX", "ABSX",
# &RTS_, &ADC_indx, &ILL_TILT, &RORADC_indx, &ILL_2NOP, &ADC_zp, &ROR_zp, &RORADC_zp,
"NONE", "INDX", "NONE", "INDX", "NONE", "ZP", "ZP", "ZP",
# &PLA_, &ADC_imm, &ROR_AC, &ILL_6B, &JMP_vec, &ADC_abs, &ROR_abs, &RORADC_abs,
"NONE", "IMM", "NONE", "IMM", "VEC", "ABS", "ABS", "ABS",
# &BVS_, &ADC_indy, &ILL_TILT, &RORADC_indy, &ILL_2NOP, &ADC_zpx, &ROR_zpx, &RORADC_zpx,
"BR", "INDY", "NONE", "INDY", "NONE", "ZPX", "ZPX", "ZPX",
# &SEI_, &ADC_absy, &ILL_1NOP, &RORADC_absy, &ILL_3NOP, &ADC_absx, &ROR_absx, &RORADC_absx,
"NONE", "ABSY", "NONE", "ABSY", "NONE", "ABSX", "ABSX", "ABSX",
# 0x80
# &ILL_2NOP, &STA_indx, &ILL_2NOP, &ILL_83, &STY_zp, &STA_zp, &STX_zp, &ILL_87,
"NONE", "INDX", "NONE", "INDX", "ZP", "ZP", "ZP", "ZP",
# &DEY_, &ILL_2NOP, &TXA_, &ILL_8B, &STY_abs, &STA_abs, &STX_abs, &ILL_8F,
"NONE", "NONE", "NONE", "IMM", "ABS", "ABS", "ABS", "ABS",
# &BCC_, &STA_indy, &ILL_TILT, &ILL_93, &STY_zpx, &STA_zpx, &STX_zpy, &ILL_97,
"BR", "INDY", "NONE", "INDY", "ZPX", "ZPX", "ZPY", "INDX",
# &TYA_, &STA_absy, &TXS_, &ILL_9B, &ILL_9C, &STA_absx, &ILL_9E, &ILL_9F,
"NONE", "ABSY", "NONE", "ABSY", "ABSX", "ABSX", "ABSY", "ABSY",
# &LDY_imm, &LDA_indx, &LDX_imm, &ILL_A3, &LDY_zp, &LDA_zp, &LDX_zp, &ILL_A7,
"IMM", "INDX", "IMM", "INDX", "ZP", "ZP", "ZP", "ZP",
# &TAY_, &LDA_imm, &TAX_, &ILL_1NOP, &LDY_abs, &LDA_abs, &LDX_abs, &ILL_AF,
"NONE", "IMM", "NONE", "NONE", "ABS", "ABS", "ABS", "ABS",
# &BCS_, &LDA_indy, &ILL_TILT, &ILL_B3, &LDY_zpx, &LDA_zpx, &LDX_zpy, &ILL_B7,
"BR", "INDY", "NONE", "INDY", "ZPX", "ZPX", "ZPY", "ZPY",
# &CLV_, &LDA_absy, &TSX_, &ILL_BB, &LDY_absx, &LDA_absx, &LDX_absy, &ILL_BF,
"NONE", "ABSY", "NONE", "ABSY", "ABSX", "ABSX", "ABSY", "ABS",
# 0xC0
# &CPY_imm, &CMP_indx, &ILL_2NOP, &DECCMP_indx, &CPY_zp, &CMP_zp, &DEC_zp, &DECCMP_zp,
"IMM", "INDX", "NONE", "INDX", "ZP", "ZP", "ZP", "ZP",
# &INY_, &CMP_imm, &DEX_, &ILL_CB, &CPY_abs, &CMP_abs, &DEC_abs, &DECCMP_abs,
"NONE", "IMM", "NONE", "IMM", "ABS", "ABS", "ABS", "ABS",
# &BNE_, &CMP_indy, &ILL_TILT, &DECCMP_indy, &ILL_2NOP, &CMP_zpx, &DEC_zpx, &DECCMP_zpx,
"BR", "INDY", "NONE", "INDY", "NONE", "ZPX", "ZPX", "ZPX",
# &CLD_, &CMP_absy, &ILL_1NOP, &DECCMP_absy, &ILL_3NOP, &CMP_absx, &DEC_absx, &DECCMP_absx,
"NONE", "ABSY", "NONE", "ABSY", "NONE", "ABSX", "ABSX", "ABSX",
# &CPX_imm, &SBC_indx, &ILL_2NOP, &INCSBC_indx, &CPX_zp, &SBC_zp, &INC_zp, &INCSBC_zp,
"IMM", "INDX", "NONE", "INDX", "ZP", "ZP", "ZP", "ZP",
# &INX_, &SBC_imm,  &NOP_, &ILL_EB, &CPX_abs, &SBC_abs, &INC_abs, &INCSBC_abs,
"NONE", "IMM", "NONE", "IMM", "ABS", "ABS", "ABS", "ABS",
# &BEQ_, &SBC_indy, &ILL_TILT, &INCSBC_indy, &ILL_2NOP, &SBC_zpx, &INC_zpx, &INCSBC_zpx,
"BR", "INDY", "NONE", "INDY", "NONE", "ZPX", "ZPX", "ZPX",
# &SED_, &SBC_absy, &ILL_1NOP, &INCSBC_absy, &ILL_3NOP, &SBC_absx, &INC_absx, &INCSBC_absx
"NONE", "ABSY", "NONE", "ABSY", "NONE", "ABSX", "ABSX", "ABSX"
);

# First param: starting address, second param: starting index into data,
# third param: name of textbox widget to populate with output,
# fourth param: TRUE if illegal instructions should be shown, too.
sub PopulateWithAssembly($$$$) {
    my ($address, $dataindex, $textbox, $showIllegal) = @_;
    my $line = '';
    my $instr;
    my $dataOp1;
    my $dataOp2;
    my $instrLen;
    my $lastdataindex = length($SIDfield{'data'});
    my $lineNo = 1;
    my $colorTag;
    my $instrLength;
    my $charNo;
    my $hexAddress;
    my $addBranchTag;
    my $branchAddress;
    my $markHex;
    my @marks;

    if ($ShowColors) {
        # Set up coloring scheme.
        $textbox->tagConfigure('addrColor', -foreground => 'darkred');
        $textbox->tagConfigure('hexColor',  -foreground => 'darkblue');
        $textbox->tagConfigure('instrColor',-foreground => 'darkgreen');
        $textbox->tagConfigure('illglColor',-foreground => 'red');
    }

    while ($address <= $loadRangeEnd) {
        $hexAddress = sprintf("%04X", $address);
        $line = ";$hexAddress    ";

        # Set a marker here so we can jump to it.
        $markHex = "mark$hexAddress";
        push(@marks, $markHex);
        $textbox->markSet($markHex, "$lineNo.0");
        $textbox->markGravity($markHex, 'left');

        $addBranchTag = 0;

        $instr = unpack("C", substr($SIDfield{'data'}, $dataindex, 1));

        $dataOp1 = undef;
        if ($dataindex+1 < $lastdataindex) {
            $dataOp1 = unpack("C", substr($SIDfield{'data'}, $dataindex+1, 1));
            $dataOp1 = sprintf('%02X', $dataOp1);
        }
        else {
            $dataOp1 = '??';
        }

        $dataOp2 = undef;
        if ($dataindex+2 < $lastdataindex) {
            $dataOp2 = unpack("C", substr($SIDfield{'data'}, $dataindex+2, 1));
            $dataOp2 = sprintf('%02X', $dataOp2);
        }
        else {
            $dataOp2 = '??';
        }

        $line .= sprintf('%02X ', $instr);

        if ($instrFlagList[$instr] eq 'DEF' or $showIllegal) {

            if (($instrTypeList[$instr] eq 'BR') or
                ($instrTypeList[$instr] eq 'IMM') or
                ($instrTypeList[$instr] eq 'INDX') or
                ($instrTypeList[$instr] eq 'INDY') or
                ($instrTypeList[$instr] eq 'ZP') or
                ($instrTypeList[$instr] eq 'ZPX') or
                ($instrTypeList[$instr] eq 'ZPY')) {

                $instrLen = 2;
                $line .= "$dataOp1    ";
            }
            elsif (($instrTypeList[$instr] eq 'VEC') or
                ($instrTypeList[$instr] eq 'ABS') or
                ($instrTypeList[$instr] eq 'ABSX') or
                ($instrTypeList[$instr] eq 'ABSY')) {

                $instrLen = 3;
                $line .= "$dataOp1 $dataOp2 ";
            }
            else {
                $instrLen = 1;
                $line .= '      ';
            }

            $line .= '   ';

            if ($ShowColors) {
                if ($instrFlagList[$instr] eq 'ILL') {
                    $colorTag = 'illglColor';
                }
                else {
                    $colorTag = 'instrColor';
                }
            }

            $line .= $instrNameList[$instr] . ' ';
            $instrLength = length($instrNameList[$instr]);

            if ($instrTypeList[$instr] eq 'BR') {
                $addBranchTag = 2;

                if ($dataOp1 eq '??') {
                    $line .= '????';
                }
                elsif (HexValue($dataOp1) < 127) {
                    $branchAddress = sprintf('%04X', $address+$instrLen+HexValue($dataOp1));
                }
                else {
                    $branchAddress = sprintf('%04X', $address+$instrLen-(256-HexValue($dataOp1)));
                }
                $line .= '$' . $branchAddress;
            }
            elsif ($instrTypeList[$instr] eq 'IMM') {
                $line .= '#$' . $dataOp1;
            }
            elsif ($instrTypeList[$instr] eq 'INDX') {
                $line .= '($' . $dataOp1 . ',X)';
            }
            elsif ($instrTypeList[$instr] eq 'INDY') {
                $line .= '($' . $dataOp1 . '),Y';
            }
            elsif ($instrTypeList[$instr] eq 'ZP') {
                $line .= '$' . $dataOp1;
            }
            elsif ($instrTypeList[$instr] eq 'ZPX') {
                $line .= '$' . $dataOp1 . ',X';
            }
            elsif ($instrTypeList[$instr] eq 'ZPY') {
                $line .= '$' . $dataOp1 . ',Y';
            }
            elsif ($instrTypeList[$instr] eq 'VEC') {
                $line .= '($' . $dataOp2 . $dataOp1 . ')';
            }
            elsif ($instrTypeList[$instr] eq 'ABS') {
                $line .= '$' . $dataOp2 . $dataOp1;
            }
            elsif ($instrTypeList[$instr] eq 'ABSX') {
                $line .= '$' . $dataOp2 . $dataOp1 . ',X';
            }
            elsif ($instrTypeList[$instr] eq 'ABSY') {
                $line .= '$' . $dataOp2 . $dataOp1 . ',Y';
            }

            $address += $instrLen;
            $dataindex += $instrLen;

            if ( (($instrNameList[$instr] eq 'JMP') and ($instrTypeList[$instr] eq 'ABS'))
                or ($instrNameList[$instr] eq 'JSR')) {

                $addBranchTag = 2;
                $branchAddress = $dataOp2 . $dataOp1;
            }

        }
        else {
            $colorTag = 'illglColor' if ($ShowColors);
            $line .= '         ';
            $line .= '***';
            $instrLength = 3;

            $address += 1;
            $dataindex += 1;
        }

        $textbox->insert('end', "$line\n");

        if ($ShowColors) {
            # Add colors.
            $textbox->tagAdd('addrColor', "$lineNo.0", "$lineNo.5");
            $textbox->tagAdd('hexColor',  "$lineNo.8", "$lineNo.17");
            $charNo = 21 + $instrLength;
            $textbox->tagAdd($colorTag,   "$lineNo.21", "$lineNo.$charNo");
        }
        else {
            $charNo = 21 + $instrLength;
        }

        if ($addBranchTag) {
            my $tempCharNo;
            my $tag;
            my $mark;

            $charNo += $addBranchTag;
            $tempCharNo = $charNo + 4;

            # Using the strings in-place doesn't work, so use these vars instead.
            $tag = "tag$branchAddress";
            $mark = "mark$branchAddress";

            # Set up clickable tags.
            $textbox->tagAdd($tag, "$lineNo.$charNo", "$lineNo.$tempCharNo");
            $textbox->tagConfigure($tag, -background => 'yellow');

            # Set up bindings so we can jump to markers.
            $textbox->tagBind($tag, '<Enter>', sub {
                    shift->tagConfigure($tag, -background => 'grey', -relief => 'raised', -borderwidth => 1);
                    $textbox->configure(-cursor => 'hand2');
                } );
            $textbox->tagBind($tag, '<Leave>', sub {
                    shift->tagConfigure($tag, -background => 'yellow', -relief => 'flat');
                    $textbox->configure(-cursor => 'xterm');
                } );
            $textbox->tagBind($tag, '<ButtonRelease>', sub {
                    if (grep(/$mark/,@marks)) {
                        # Use 'yview' instead of 'see' to show mark on top, not in middle.
                        shift->yview($mark);
                    }
                    else {
                        # Try to find the closest mark if this one doesn't exist.
                        my $index = 0;

                        while (($marks[$index] lt $mark) and ($index <= $#marks)) {
                            $index++;
                        }

                        if ($index > 0) {
                            $index--;
                        }

                        shift->yview($marks[$index]);
                    }
                } );
        }

        # Add a line to improve readability (mostly to separate subroutines).
        if ( ($instrNameList[$instr] eq 'JMP') or ($instrNameList[$instr] eq 'RTS') ) {
            $textbox->insert('end', ';' . '-' x 31 . "\n");
            $lineNo++;
        }

        $lineNo++;
    }

    # Display given line on top.
    if (grep(/$JumpToMark/,@marks)) {
        # Use 'yview' instead of 'see' to show mark on top, not in middle.
        $textbox->yview($JumpToMark);
    }
    else {
        # Try to find the closest mark if this one doesn't exist.
        my $index = 0;

        while (($marks[$index] lt $JumpToMark) and ($index <= $#marks)) {
            $index++;
        }

        if ($index > 0) {
            $index--;
        }

        $textbox->yview($marks[$index]);
    }
}

##############################################################################
#
# File operations
#
##############################################################################

sub Delete {
    my $index = $filelistbox->curselection();
    my $tempfilename;

    unless (defined($index)) {
        ErrorBox("No file is selected!");
        $STATUS = "Nothing was deleted.";
        return;
    }

    $tempfilename = $filelistbox->get($index);

    if ($ConfirmDelete) {
        unless (YesNoBox("$tempfilename\nAre you sure you want to delete it?",
            'Delete confirmation')) {
            $STATUS = "$tempfilename is not deleted.";
            return;
        }
    }

    unless (unlink($tempfilename)) {
        ErrorBox("Error deleting $tempfilename!");
        $STATUS = "Nothing was deleted.";
        return;
    }

    ScanDir(0);
    $STATUS = "$tempfilename is deleted.";
}

sub NewFile {
    if (SaveChanges()) {
        return;
    }

    # Initialize values.
    $modified = 0;           # This is 1 if any SID field was modified.
    $filename = '<NONE>';    # Just so that we display something initially.
    $filesize = 0x7C;
    $realLoadAddress = 0;
    $loadRangeEnd = 0;
    $loadRange = '$0000 - $0000';
    $SIDMD5 = '<NONE>';
    $MUSPlayer = 0;
    $PlaySID = 0;
    $Video = 0;
    $SIDChip = 0;

    $mySID->initialize();
    PopulateSIDfields();
    UpdateMagicIDFields();
    UpdateFlags();

    $window->update();
}

# Returns TRUE if the file got saved, FALSE otherwise.
sub SaveAs {
    my $types;
    my $initialdir;
    my $initialfile;
    my $myPath;

    if ($AlwaysGoToSaveDir) {
        $lastSaveDir = $SaveDirectory;
    }

    unless ($lastSaveDir) {
        if ($isWindows) {
            $initialdir = $drive . $directory;
        }
        else {
            $initialdir = $directory;
        }
    }
    else {
        $initialdir = $lastSaveDir;
    }

    if ($filename !~ /^[a-zA-Z0-9_\.-]+$/) {
        # Filename contains potential illegal chars, this would prevent the Save File window from appearing.
        $initialfile = '';
    }
    else {
        $initialfile = $filename;
    }

    $types = [['SID files', ['.sid']], ['All files', '*']];

    $myPath = $window->getSaveFile(
        -filetypes => $types,
        -initialdir => $initialdir,
        -initialfile => $initialfile,
        -title => 'SIDedit - Save as...'
    );

    if ($myPath) {
        if ($myPath !~ /\.sid$/i) {
            $myPath .= '.sid';
        }

        $lastSaveDir = dirname($myPath);
        $lastSaveDir =~ s~/~\\~g if ($isWindows);
        $filename = basename($myPath);
        Save(0, $myPath);
        return 1;
    }
    else {
        return 0;
    }
}

# First param: TRUE if ask for overwrite case,
# second param: optional full path to save to.
# Returns TRUE if the file got saved, FALSE otherwise.
sub Save {
    my ($askOverwrite, $SavePath) = @_;
    my $field;
    my $SaveFilename;
    my $askConfirmSave = 1;
    my $oldSavePath;

    if (!$SavePath) {
        $SaveFilename = $filename;
        $SavePath = $filename;
    }
    else {
        $SaveFilename = basename($SavePath);
        $askConfirmSave = 0;
    }

    if (FieldsNotValid()) {
        $STATUS = "SID fields are not valid, save operation was canceled.";
        return 0;
    }

    if (-e "$SavePath") {
        if ($askOverwrite) {
            unless (YesNoBox("File $SaveFilename exists - overwrite?",
                'Save confirmation')) {
                $STATUS = "Save operation was canceled.";
                return 0;
            }
        }

        # Rename existing file in case we have a case change in filename.
        $oldSavePath = $SavePath;
        move($SavePath, $SavePath . "_$$");

    }
    elsif ($ConfirmSave and $askConfirmSave) {
        unless (YesNoBox("Save to $SaveFilename?",
            'Save confirmation')) {
            $STATUS = "Save operation was canceled.";
            return 0;
        }
    }

    $mySID->set('version', $SIDfield{'version'});

    foreach $field (@SIDfields) {
        next if ($field eq 'data');
        next if (($field eq 'magicID') and ($SIDfield{'version'} == 1));

        if (grep(/^$field$/, @hexFields) or
            grep(/^$field$/, @c64hexFields)) {

            next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
            # Get data out of the hex fields.
            $mySID->set($field, HexValue($SIDfield{$field}, 4));
        }
        elsif (grep(/^$field$/, @longhexFields)) {
            next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
            # Get data out of the hex fields.
            $mySID->set($field, HexValue($SIDfield{$field}, 8));
        }
        elsif (grep(/^$field$/, @shorthexFields)) {
            next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));
            # Get data out of the hex fields.
            $mySID->set($field, HexValue($SIDfield{$field}, 2));
        }
        else {
            $mySID->set($field, $SIDfield{$field});
        }
    }

    unless ($mySID->write('-filename' => $SavePath)) {
        # There was an error when trying to save the file.
        ErrorBox("Error saving $SaveFilename!\n(Maybe the filename has invalid characters in it.)");
        $STATUS = "Error saving $SaveFilename!";

        # Restore old file if any.
        if ($oldSavePath) {
            move($SavePath . "_$$", $oldSavePath);
        }

        return 0;
    }

    # Remove temporary file if any.
    if ($oldSavePath) {
        unlink($SavePath . "_$$");
    }

    $modified = 0;

    # The filename might have changed, so update the file lists.
    ScanDir(0);

    $STATUS = "$SaveFilename is saved to disk.";
    $window->update();

    return 1;
}

# First param: optional dummy variable, not used,
# second param: optional, key pressed.
sub FileSelect {
    my ($notused, $keyPressed) = @_;
    my $index = $filelistbox->curselection();
    my $tempfilename;
    my $oldversion;
    my ($rootname, $extension);
    my $loaded = 0;
    my $FH;
    my $infoFile = 0;

    # Handle alphanumeric char to jump to entry starting with that letter(s).

    if (defined($keyPressed) and $keyPressed =~ /^([a-zA-Z0-9_-])$/) {
        HandleKeypress($keyPressed, $filelistbox, $index);
    }

    $index = $filelistbox->curselection();
    return unless (defined($index));

    if (SaveChanges()) {
        return;
    }

    $modified = 0;
    $oldversion = $SIDfield{'version'};

    $tempfilename = $filelistbox->get($index);
    ($rootname, $extension) = split (/\./, $tempfilename);

    unless ($FH = new FileHandle ("< $tempfilename")) {
        ErrorBox("Error reading $tempfilename!");
        $STATUS = "Error reading $tempfilename!";
        return;
    }

    # This check is needed because INFO files can also have the .sid extension.
    if ($ListInfoFiles and (<$FH> =~ /^\s*SIDPLAY\s+INFOFILE\s*$/)) {
        $infoFile = 1;
    }

    # Go back to restore eaten line.
    seek($FH, 0, 0);

    if ($infoFile) {
        # Load INFO file.

        # Ask user if this is what was the intent.
        unless (YesNoBox("Load SID header info from $tempfilename?")) {
            $STATUS = "Load aborted.";
            return;
        }

        # Defaults are needed in case they are not defined in the INFO file.
        $mySID->set('startSong' => 1);
        if ($SIDfield{'version'} == 2) {
            $mySID->set('flags' => 0);
            $mySID->set('startPage' => 0);
            $mySID->set('pageLength' => 0);
        }

        while(<$FH>) {
            if (/^\s*SONGS\s*=\s*(.*)$/i) {
                my $songs;
                my $startSong;

                ($songs, $startSong) = split (/\s*,\s*/,$1);
                $startSong = 1 unless ($startSong);
                $mySID->set('songs' => $songs);
                $mySID->set('startSong' => $startSong);
            }
            elsif (/^\s*ADDRESS\s*=\s*(.*)$/) {
                my $loadAddress;
                my $initAddress;
                my $playAddress;

                ($loadAddress, $initAddress, $playAddress) = split (/\s*,\s*/,$1);
                $mySID->set('loadAddress' => HexValue($loadAddress,4));
                $mySID->set('initAddress' => HexValue($initAddress,4));
                $mySID->set('playAddress' => HexValue($playAddress,4));
            }
            elsif (/^\s*SPEED\s*=\s*(.*)$/i) {
                $mySID->set('speed' => HexValue($1,8));
            }
            elsif (/^\s*NAME\s*=\s*(.*)$/i) {
                $mySID->set('name' => $1);
            }
            elsif (/^\s*AUTHOR\s*=\s*(.*)$/i) {
                $mySID->set('author' => $1);
            }
            elsif (/^\s*COPYRIGHT\s*=\s*(.*)$/i) {
                $mySID->set('released' => $1);
            }
            elsif (/^\s*RELEASED\s*=\s*(.*)$/i) {
                $mySID->set('released' => $1);
            }
            elsif ($SIDfield{'version'} == 2) {
                if (/^\s*SIDSONG\s*=\s*(.*)$/i) {
                    if ($1 =~ /YES/i) {
                        $mySID->setMUSPlayer(1);
                    }
                }
                elsif (/^\s*COMPATIBILITY\s*=\s*(.*)$/i) {
                    if ($1 =~ /PSID/i) {
                        $mySID->set('magicID' => 'PSID');
                        $mySID->setPlaySID(1);
                    }
                    elsif ($1 =~ /R64/i) {
                        $mySID->set('magicID' => 'RSID');
                    }
                    elsif ($1 =~ /C64/i) {
                        $mySID->set('magicID' => 'PSID');
                    }
                    elsif ($1 =~ /BASIC/i) {
                        # This also sets 'initAddress' to 0.
                        $mySID->set('magicID' => 'RSID');
                        $mySID->setC64BASIC(1);
                    }                 }
                elsif (/^\s*CLOCK\s*=\s*(.*)$/i) {
                    $mySID->setClockByName($1);
                }
                elsif (/^\s*SIDMODEL\s*=\s*(.*)$/i) {
                    $mySID->setSIDModelByName($1);
                }
                elsif (/^\s*RELOC\s*=\s*(.*)$/i) {
                    my $start;
                    my $length;

                    ($start, $length) = split (/\s*,\s*/, $1);

                    $mySID->set('startPage' => HexValue($start,2));
                    $mySID->set('pageLength' => HexValue($length,2));
                }
            }
        }

        $modified = 1;
        $STATUS = "Read content of $tempfilename to SID header.";
        $loaded = 1;
    }

    if (!$infoFile and $ListSIDFiles and grep(/^$extension$/i, @sidfiles)) {
        # Load SID file.

        if(!$mySID->read('-filename' => $tempfilename)) {
            # Error.
            ErrorBox("Error reading $tempfilename or unrecognized format!");
            $STATUS = "Error reading $tempfilename!";
            return;
        }
        else {
            # All OK, loaded SID file.
            $STATUS = "$tempfilename is loaded into memory.";
            $loaded = 1;
        }
    }

#    if (grep(/^$extension$/i, @datfiles)) {	XXX
        # Load file as SID data.

        # Ask user if this is what was the intent.
        unless (YesNoBox("Load $tempfilename as SID data?")) {
            $STATUS = "Load aborted.";
            return;
        }

        # Read in as data, set $mySID to defaults.

        my $data;

        if (YesNoBox("Reset SID header data to defaults?")) {
            $mySID->initialize();
        }

        # Can't be bigger than the C64's memory.
        binmode $FH;
        read($FH, $data, 65536);
        $mySID->set("data" => $data);

        $modified = 1;
        $STATUS = "Read $tempfilename as SID data.";
        $loaded = 1;

        # Rename extension.
        $tempfilename = $rootname . ".sid";
        $mySID->setFileName($tempfilename);
#    }

    $FH->close();

    unless ($loaded) {
        # This is an error.
        ErrorBox("Unrecognized file format!");
        $STATUS = "Error reading $tempfilename!";
        return;
    }

    $filename = $tempfilename;

    PopulateSIDfields();

    if ($oldversion != $SIDfield{'version'}) {
        UpdateV2Fields();
    }

    UpdateMagicIDFields();
    UpdateFlags();

    $window->update();
}

sub PopulateSIDfields {
    my $field;

    foreach $field (@SIDfields) {
        $SIDfield{$field} = $mySID->get($field);
        unless (defined($SIDfield{$field})) {
            $SIDfield{$field} = 0;
        }
    }

    $filesize = $mySID->getFileSize();

    $realLoadAddress = $mySID->getRealLoadAddress();
    $loadRangeEnd = $realLoadAddress + length($SIDfield{'data'}) - 1;
    if ($loadRangeEnd < 2) {
        $loadRangeEnd = 0;
    }
    elsif ($SIDfield{'loadAddress'} == 0) {
        $loadRangeEnd -= 2;
    }

    $loadRange = sprintf('$%04X - $%04X', $realLoadAddress, $loadRangeEnd);

    # Hex fields will be displayed as hex.
    foreach $field (@hexFields) {
        $SIDfield{$field} = sprintf("0x%04X", $SIDfield{$field});
    }

    # It's a 4-byte hex field.
    foreach $field (@longhexFields) {
        $SIDfield{$field} = sprintf("0x%08X", $SIDfield{$field});
    }

    # It's a 1-byte hex field.
    foreach $field (@shorthexFields) {
        $SIDfield{$field} = sprintf('$%02X', $SIDfield{$field});
    }

    foreach $field (@c64hexFields) {
        $SIDfield{$field} = sprintf('$%04X', $SIDfield{$field});
    }

    $SIDMD5 = $mySID->getMD5();

    CheckVersion();
    UpdateFlags();
}

# First param: name of app to execute, must be 'SID player' or 'hex editor'.
sub LaunchApp($) {
    my ($AppName) = @_;
    my $AppCommand;
    my $AppCommandOptions;
    my $frame;
    my $win;
    my $index = $filelistbox->curselection();
    my $tempfilename;
    my $buttonPressed = 0;
    my $pid;

    if ($AppName =~ /SID player/) {
        $AppCommand = $SIDPlayer;
        $AppCommandOptions = $SIDPlayerOptions;
    }
    elsif ($AppName =~ /hex editor/) {
        $AppCommand = $HexEditor;
        $AppCommandOptions = $HexEditorOptions;
    }
    else {
        return;
    }

    unless (defined($index)) {
        ErrorBox("No file is selected! Please, select a file first.");
        $STATUS = "Error launching the $AppName!";
        return;
    }

    $tempfilename = $filelistbox->get($index);

    if ($modified) {
        ErrorBox("The SID file was modified but not saved. Please, save the file first!");
        $STATUS = "The $AppName was not launched because modified SID file is not saved, yet.";
        return;
    }

    if (!-x $AppCommand or ($isWindows and !-f $AppCommand)) {
        Settings('tool');
        return;
    }

    # Now we can play the file.

    if ($isWindows) {
        my $ProcessObj;

        unless (Win32::Process::Create($ProcessObj,
            "$AppCommand",
            "$AppCommandOptions \"$drive$directory" . $separator . "$tempfilename\"",
            0,
            'DETACHED_PROCESS' | 'NORMAL_PRIORITY_CLASS',
            "$drive$directory")) {

            ErrorBox("Win32 error:\n" . Win32::FormatMessage( Win32::GetLastError() ));
            $STATUS = "There was an error trying to run your $AppName!";
            return;
        }
    }
    else {
        if ($pid = fork()) {
            # Parent will have zombies, but who cares?
        }
        elsif (defined($pid)) {
            # Child process.
            exec("$AppCommand $AppCommandOptions \"$directory" . $separator . "$tempfilename\"");
        }
    }

    $STATUS = "The $AppName was launched with $filename.";
}

# First param: parent window widget.
sub ShowLastToolOutput($) {
    my ($parent) = @_;

    ShowTextBox($parent, 'External tool command output', $ToolOutput);
}

sub RunTool {
    my $win;
    my $index = $filelistbox->curselection();
    my $buttonPressed = 0;
    my $tool;
    my $waitwin;
    my $cmdline;
    my $listwidget;
    my $listindex = -1;
    my $filenameNoExt;

    unless (defined($index)) {
        ErrorBox("No file is selected! Please, select a file first.");
        $STATUS = "Error launching external tool!";
        return;
    }

    if ($modified) {
        ErrorBox("The SID file was modified but not saved. Please, save the file first!");
        $STATUS = "External tool was not launched because modified SID file is not saved, yet.";
        return;
    }

    $filenameNoExt = $filename;
    $filenameNoExt =~ s/\.[a-zA-Z0-9]+$//;

    $win = $window->Toplevel();
    $win->transient($window);

    $win->title("SIDedit - Run tool");

    $tool = $ToolList[0];

    $frame = $win->Frame()
        ->pack(@topPack, @bothFill, -pady => 5, -padx => 5);
    $frame->Label(-text => "Enter the command line for the external tool you wish to use\nor choose from a previously entered one.")
        ->grid(-column => 0, -row => 0, -sticky => 'ew');
    $frame->Label(
        -justify => 'left',
        -text => "Command line substitutions:\n\n\%f - full pathname of currently selected file\n\%x - full pathname of currently selected file without extension\n\%d - full pathname of current directory\n")
        ->grid(-column => 0, -row => 1, -sticky => 'w');

    $frame->Label(-text => "Command line:")
        ->grid(-column => 0, -row => 2, -sticky => 'e');
    $listwidget = $frame->BrowseEntry(
        -label => "Command line:",
        -variable => \$tool,
        -choices => \@ToolList)
        ->grid(-column => 0, -row => 2, -sticky => 'ew');
    $listwidget->focus();

    $listwidget->bind("<Return>", sub { $buttonPressed = 1; } );
    $listwidget->bind("<Down>", sub { $listindex++ if ($listindex < $#ToolList); $tool = $ToolList[$listindex]; } );
    $listwidget->bind("<Up>", sub { if ($listindex > 0) {$listindex--; $tool = $ToolList[$listindex];} } );

    sub ShowLastOut {
        ShowLastToolOutput($win);
        $win->grab();
        $win->focus();
        $win->raise();
        $listwidget->focus();
    }

    $frame = $win->Frame()
        ->pack(@topPack, @bothFill);
    $frame->Button(-text => 'Run', -underline => 0, -width => 10,
        -command => sub { $buttonPressed = 1; } )
        ->grid(-column => 1, -row => 0, -padx => 5, -pady => 5);
    $frame->Button(-text => 'Cancel', -underline => 0, -width => 10,
        -command => sub { $buttonPressed = 2; } )
        ->grid(-column => 2, -row => 0, -padx => 5, -pady => 5);
    $frame->Button(-text => 'Show last output', -underline => 0,
        -command => sub { ShowLastOut(); } )
        ->grid(-column => 3, -row => 0, -padx => 5, -pady => 5);

    $win->bind("<Return>", sub { $buttonPressed = 1; } );
    $win->bind("<Control-r>" => sub { $buttonPressed = 1; });
    $win->bind("<Alt-r>" => sub { $buttonPressed = 1; });

    $win->bind("<Escape>", sub { $buttonPressed = 2; } );
    $win->bind("<Control-c>" => sub { $buttonPressed = 2; });
    $win->bind("<Alt-c>" => sub { $buttonPressed = 2; });

    $win->bind("<Control-s>" => sub { ShowLastOut(); } );
    $win->bind("<Alt-s>" => sub { ShowLastOut(); } );

    $win->resizable(0,0);
    $win->Popup();
    $win->grab();
    $win->focus();
    $win->waitVariable(\$buttonPressed);
    $win->grabRelease();
    $win->withdraw();

    if ($buttonPressed == 1) {

        # Strip whitespace.
        $tool =~ s/^\s*//g;
        $tool =~ s/\s*$//g;

        # Empty line was entered.
        return unless ($tool);

        # Redo list so most recently entered command line is on top.

        my @newList;

        foreach (@ToolList) {
            push (@newList, $_) if ($_ ne $tool);
        }

        unshift(@newList, $tool);
        @ToolList = @newList;

        # Keep the list length in control.
        pop(@ToolList) if ($#ToolList >= $ToolListMaxLength);
    }
    else {
        return;
    }

    # Execute tool.

    $cmdline = $tool;

    if ($isWindows) {
        my $TMP;

        $cmdline =~ s/\%f/\"$drive$directory$separator$filename\"/g;
        $cmdline =~ s/\%d/\"$drive$directory\"/g;
        $cmdline =~ s/\%x/\"$drive$directory$separator$filenameNoExt\"/g;

        $ToolOutput = "COMMAND LINE EXECUTED:\n$cmdline\n\n";

        $cmdline .= " > $$.tmp";

        system($cmdline);

        unless ($TMP = new FileHandle ("< $$.tmp")) {
            ErrorBox("Error reading output of tool!");
            $STATUS = "Error while executing external tool!";
            return;
        }

        while (<$TMP>) {
            $ToolOutput .= $_;
        }

        $TMP->close();
        unlink("$$.tmp");
    }
    else {
        $cmdline =~ s/\%f/\"$directory$separator$filename\"/g;
        $cmdline =~ s/\%d/\"$directory\"/g;
        $cmdline =~ s/\%x/\"$directory$separator$filenameNoExt\"/g;
        $cmdline .= ' 2>&1';

        $ToolOutput = "COMMAND LINE EXECUTED:\n$cmdline\n\n";

        # Pop up a window while executing the tool.

        $waitwin = $window->Toplevel();
        $waitwin->Label(-text => "Running external tool.\n\nPlease wait!")
            ->pack(@topPack);
        $waitwin->title("SIDedit - Executing external tool");

        $win->Busy(-recurse => 1);

        $waitwin->resizable(0,0);
        $waitwin->Popup();
        $waitwin->grab();

        $ToolOutput .= qx($cmdline);

        $waitwin->grabRelease();
        $waitwin->withdraw();

        $win->Unbusy();
    }

    ShowLastToolOutput($win);
}

##############################################################################
#
# Dir operations
#
##############################################################################

sub DeleteDir {
    my $index = $dirlistbox->curselection();
    my $tempdirname;

    unless (defined($index)) {
        ErrorBox("No directory is selected!");
        $STATUS = "Nothing was deleted.";
        return;
    }

    $tempdirname = $dirlistbox->get($index);

    if ($tempdirname eq '[..]') {
        $STATUS = "Parent directory entry cannot be deleted.";
        return;
    }

    if ($ConfirmDelete) {
        unless (YesNoBox("$tempdirname\nAre you sure you want to delete this directory?",
            'Delete confirmation')) {
            $STATUS = "$tempdirname is not deleted.";
            return;
        }
    }

    # Dirnames might be enclosed in square braces.
    $tempdirname =~ s/^\[//;
    $tempdirname =~ s/\]$//;

    unless (rmdir($tempdirname)) {
        ErrorBox("Error deleting [$tempdirname]!");
        $STATUS = "Nothing was deleted.";
        return;
    }

    ScanDir(0);
    $STATUS = "[$tempdirname] directory is deleted.";

    $dirlistbox->activate(0);
    $dirlistbox->see(0);
    $dirlistbox->selectionClear(0, 'end');
    $dirlistbox->selectionSet(0);
}

# First param: is this a new dir (1) or just a re-scan (0)?
sub ScanDir {
    my ($newdir) = @_;
    my @allFiles;
    my $extension;
    my $file;
    my $indexofcurrent;
    my $index;
    my $oldindex = undef;

    if ($ListSIDFiles != 1 and $ListDataFiles != 1 and $ListInfoFiles != 1) {
        $ListSIDFiles = 1;
    }

    $oldindex = $filelistbox->curselection();

    $dirlistbox->delete(0, 'end');
    $filelistbox->delete(0, 'end');

    if ($isWindows) { # XXX
		# it seems this crap fails miserably when relative
		# path contains non ascii chars.. what a joke
		my $sep = File::Spec->catfile('', '');
		my $fullpath= $drive.$sep.$directory;		
		$fullpath =  encode cp1252 => $directory; # https://de.wikipedia.org/wiki/Windows-1252
		
		opendir(DIR, $fullpath) or print STDOUT "ERROR: FAILED TO OPEN DIR\n";	
   } else {
		opendir(DIR, $directory) or print STDOUT "ERROR: FAILED TO OPEN DIR\n";	
   }   
#    opendir(DIR, $directory);	
    @allFiles = sort {uc($a) cmp uc($b)} readdir(DIR);
    closedir(DIR);

    $index = 0;
    $indexofcurrent = -1;

    foreach $file (@allFiles) {
        if (-d $file) {
            next if ($file eq '.');
            $dirlistbox->insert('end', "[$file]");
        }
        if (-f $file) {
            # This is our filter mechanism.
						
            if ($ListAllFiles) { 	# XXX
				$filelistbox->insert('end', $file);
				if (!$modified and ($filename eq $file)) {
					$indexofcurrent = $index;
				}
				$index++;
				next;
			}

            if ($file =~ /\.(\S+)$/) {
                $extension = $1;
                if ($ListDataFiles) {
                    if (grep(/^$extension$/i, @datfiles)) {
                        $filelistbox->insert('end', $file);
                        if (!$modified and ($filename eq $file)) {
                            $indexofcurrent = $index;
                        }
                        $index++;
                        next;
                    }
                }

                if ($ListInfoFiles) {
                    if (grep(/^$extension$/i, @inffiles)) {
                        $filelistbox->insert('end', $file);
                        if (!$modified and ($filename eq $file)) {
                            $indexofcurrent = $index;
                        }
                        $index++;
                        next;
                    }
                }

                if ($ListSIDFiles) {
                    if (grep(/^$extension$/i, @sidfiles)) {
                        $filelistbox->insert('end', $file);
                        if (!$modified and ($filename eq $file)) {
                            $indexofcurrent = $index;
                        }
                        $index++;
                        next;
                    }
                }
            }
        }
    }

    # We make sure that when we save or delete a file, the currently saved
    # file or the one after the deleted one gets automatically selected.

    if (($indexofcurrent == -1) and (defined($oldindex) and ($oldindex >= 0))) {
        $indexofcurrent = $oldindex;
    }

    if (!$newdir and ($indexofcurrent >= 0)) {
        $filelistbox->activate($indexofcurrent);
        $filelistbox->see($indexofcurrent);
        $filelistbox->selectionClear(0, 'end');
        $filelistbox->selectionSet($indexofcurrent);
    }

    FileSelect();
    $window->update();
}

sub DirSelect {
    my $dir;
    my $index = $dirlistbox->curselection();
    my $notused = shift;
    my $keyPressed = shift;

    # Handle alphanumeric char to jump to entry starting with that letter(s).

    if ($keyPressed =~ /^([a-zA-Z0-9_-])$/) {
        HandleKeypress($keyPressed, $dirlistbox, $index);
        return;
    }
    elsif ($keyPressed eq '=CHDIR') {

        return unless (defined($index));

        $dir = $dirlistbox->get($index);
        ChangeToDir($dir);
    }
}

# First param: parent window widget, second param: ref. to dir to set.
# Returns TRUE if dir was selected, FALSE otherwise.
sub DirTreeDialog($$) {
    my ($dialog, $dir) = @_;
    my $myPath;
    my $answer;

    $myPath = $$dir;

    my $d = $dialog->DialogBox(
            -title => "SIDedit - Choose default (home) directory",
            -buttons => ["OK", "Cancel"]);

    # Stupid dialog box doesn't provide default key-bindings.
    foreach ($d->children()) {
        if ($_->name() eq "bottom") {
            foreach $wid ($_->children()) {
                if ($wid->name() =~ /button/i) {
                    $wid->configure(-underline => 0);
                }
            }
        }
    }

    # This is a _VERY_ ugly hack:
    $d->bind("<o>", sub {$d->{'selected_button'} = "OK";} );
    $d->bind("<O>", sub {$d->{'selected_button'} = "OK";} );
    $d->bind("<c>", sub {$d->{'selected_button'} = "Cancel";} );
    $d->bind("<C>", sub {$d->{'selected_button'} = "Cancel";} );
    $d->bind("<Return>", sub {$d->{'selected_button'} = "OK";} );
    $d->bind("<Escape>", sub {$d->{'selected_button'} = "Cancel";} );

    my $f = $d->add("Frame")->pack(@topPack, @bothFill, @expand);

    $dg = $f->Scrolled('DirTree',
        -scrollbars => 'osoe',
        -width => 35,
        -height => 20,
        -selectmode => 'browse',
        -exportselection => 1,
        -directory => $myPath,
        -browsecmd => sub { $myPath = shift; },
        -command   => sub { $dg->opencmd($_[0]); },
    )->pack(@bothFill, @expand);

    # Mousewheel support - experimental.
    $dg->bind("<4>", ['yview', 'scroll', +5, 'units']);
    $dg->bind("<5>", ['yview', 'scroll', -5, 'units']);
    $dg->bind('<MouseWheel>',
              [ sub { $_[0]->yview('scroll',-($_[1]/120)*3,'units') }, Tk::Ev("D")]);

    $d->protocol('WM_DELETE_WINDOW', undef);
    $answer = $d->Show();

    if ($answer eq 'OK') {
        $myPath .= $separator;
        $myPath =~ s~/~\\~g if ($isWindows);
        $$dir = $myPath;
        return 1;
    }

    return 0;
}

# First param: full path of dir to change to.
sub ChangeToDir($) {
    my ($dir) = @_;
    my $olddir = $directory;
    my $olddrive;
    my @subdirs;
    my $scandir = 0;

    if (ref($dir)) {
        $dir = $$dir;
    }

    if ($isWindows) {
        $olddrive = $drive;
    }

    if (!$dir) {
        # Dir name is empty most likely because some dir shortcut is not set.
        Settings('file');
        return;
    }

    # Dirnames may be enclosed in square braces.
    $dir =~ s/^\[//;
    $dir =~ s/\]$//;

	# XXX orig impl fails for whitespace in folder names
	if (!(($dir eq "..") or ($dir =~ /^([a-z]|[A-Z]):/))) {
		my $sep = File::Spec->catfile('', '');
		$dir = Cwd::cwd().$sep.$dir;
		
		# it also fails for non ascii chars in folder names (at least on Windows)
		$dir =  encode cp1252 => $dir; # https://de.wikipedia.org/wiki/Windows-1252
	}
	
    unless (chdir($dir)) {
        # Whoops, couldn't change to the specified directory.
        if ($isWindows) {
            if ($drive eq $dir) {
                ErrorBox("Can't read from drive $drive!");
            }
            elsif ($dir =~ /^\D:/) {
                ErrorBox("Can't change directory to $dir!");
            }
            else {
                ErrorBox("Can't change directory to $drive$dir!");
            }
        }
        else {
            ErrorBox("Can't change directory to $dir!");
        }
    }
    else {
        $scandir = 1;
    }

    # Dir scan done in this order prevents "jumping" effect on dir entry display.
    $directory=cwd;

    GetDriveAndDir() if ($isWindows);

    ScanDir(1) if $scandir;

    if (($olddir =~ /^\Q$directory$separator\E(.+)$/) and
        (($isWindows and ($olddrive eq $drive)) or
         !$isWindows)) {

        my $pointto = $1;
        my @list = $dirlistbox->get(0, 'end');
        my $myindex = 0;

        foreach (@list) {
            if ($list[$myindex] =~ /^\[$pointto\]/i) {
                $dirlistbox->activate($myindex);
                $dirlistbox->see($myindex);
                $dirlistbox->selectionClear(0, 'end');
                $dirlistbox->selectionSet($myindex);
                last;
            }
            $myindex++;
        }
    }
    else {
        $dirlistbox->activate(0);
        $dirlistbox->see(0);
        $dirlistbox->selectionClear(0, 'end');
        $dirlistbox->selectionSet(0);
    }
}

# Windows only.
sub GetDriveAndDir {
    my $dir = $directory;

    # Split up full pathname to drive + directory components.
    $drive = uc(substr($directory, 0, 2));
    $dir = substr($directory, 2);
    $dir =~ s~/~\\~g;
    $directory = $dir;

    if ($drivelistbox and !$drivelistbox_called) {
        $drivelistbox_called = 1;
        $drivelistbox->setOption($drive);
    }
    else {
        $drivelistbox_called = 0;
    }
}

sub MakeDir {
    my $dialog;
    my $newdir;
    my $answer;
    my $entry;

    $dialog = $window->DialogBox(
        -title => "SIDedit - Enter name for new directory",
        -buttons => ["Create new dir", "Cancel"]);
    $dialog->add("Label", -text => "Enter dirname:")
        ->pack(@leftPack);
    $entry = $dialog->add("Entry", -textvariable => \$newdir, -width => 30)
        ->pack(@rightPack);


    # Stupid dialog box doesn't provide default key-bindings.
    foreach ($dialog->children()) {
        if ($_->name() eq "bottom") {
            foreach $wid ($_->children()) {
                if ($wid->name() =~ /button/i) {
                    $wid->configure(-underline => 1);
                }
            }
        }
    }

    # This is a _VERY_ ugly hack:
    $dialog->bind("<Control-r>", sub {$dialog->{'selected_button'} = "Create new dir";} );
    $dialog->bind("<Alt-r>", sub {$dialog->{'selected_button'} = "Create new dir";} );
    $dialog->bind("<Control-a>", sub {$dialog->{'selected_button'} = "Cancel";} );
    $dialog->bind("<Alt-a>", sub {$dialog->{'selected_button'} = "Cancel";} );
    $dialog->bind("<Control-c>", sub {$dialog->{'selected_button'} = "Cancel";} );
    $dialog->bind("<Alt-c>", sub {$dialog->{'selected_button'} = "Cancel";} );

    $dialog->protocol('WM_DELETE_WINDOW', undef);
    $entry->focus();
    $answer = $dialog->Show();

    if ($newdir and ($answer =~ /Create/i)) {
        unless (mkdir($newdir)) {
            # Whoops, couldn't create specified directory.
            ErrorBox("Error creating directory $newdir!");
            $STATUS = "Couldn't create new directory!";
        }
        else {
            $STATUS = "Created $newdir directory.";
            ScanDir(0);

            # Highlight the just created dir.

            my @list = $dirlistbox->get(0, 'end');
            my $myindex = 0;

            foreach (@list) {
                if ($list[$myindex] =~ /^\[$newdir\]/i) {
                    $dirlistbox->activate($myindex);
                    $dirlistbox->see($myindex);
                    $dirlistbox->selectionClear(0, 'end');
                    $dirlistbox->selectionSet($myindex);
                    last;
                }
                $myindex++;
            }
        }
    }
}

##############################################################################
#
# Clipboard operations
#
##############################################################################

sub CopyToClipboard {
    my $textToCopy = '';
    my $field;

    if (FieldsNotValid()) {
        $STATUS = "SID fields are not valid: copy operation is canceled.";
        return;
    }

    if ($isWindows) {
        Win32::Clipboard::Empty();
    }
    else {
        $window->clipboardClear();
    }

    if ($CopyHow eq 'info_style') {
        my $temptext;

        $textToCopy .= "SIDPLAY INFOFILE\n";
        $temptext = $SIDfield{loadAddress};
        $temptext =~ s/^\x24//;
        $textToCopy .= "ADDRESS=$temptext,";
        $temptext = $SIDfield{initAddress};
        $temptext =~ s/^\x24//;
        $textToCopy .= "$temptext,";
        $temptext = $SIDfield{playAddress};
        $temptext =~ s/^\x24//;
        $textToCopy .= "$temptext\n";

        $temptext = $SIDfield{speed};
        $temptext =~ s/^0x//;
        $textToCopy .= "SPEED=$temptext\n";

        $textToCopy .= "SONGS=$SIDfield{songs},$SIDfield{startSong}\n";
        $textToCopy .= "NAME=$SIDfield{name}\n";
        $textToCopy .= "AUTHOR=$SIDfield{author}\n";
        $textToCopy .= "RELEASED=$SIDfield{released}\n";

        if ($SIDfield{'version'} == 2) {
            if ($MUSPlayer) {
                $textToCopy .= "SIDSONG=YES\n";
            }
            else {
                $textToCopy .= "SIDSONG=NO\n";
            }

            if ($PlaySID) {
                $textToCopy .= "COMPATIBILITY=PSID\n";
            }
            elsif ($C64BASIC) {
                $textToCopy .= "COMPATIBILITY=BASIC\n";
            }
            else {
                if ($SIDfield{'magicID'} eq 'RSID') {
                    $textToCopy .= "COMPATIBILITY=R64\n";
                }
                else {
                    $textToCopy .= "COMPATIBILITY=C64\n";
                }
            }

            if ($Video == 0) {
                $textToCopy .= "CLOCK=UNKNOWN\n";
            }
            elsif ($Video == 1) {
                $textToCopy .= "CLOCK=PAL\n";
            }
            elsif ($Video == 2) {
                $textToCopy .= "CLOCK=NTSC\n";
            }
            elsif ($Video == 3) {
                $textToCopy .= "CLOCK=ANY\n";
            }

            if ($SIDChip == 0) {
                $textToCopy .= "SIDMODEL=UNKNOWN\n";
            }
            elsif ($SIDChip == 1) {
                $textToCopy .= "SIDMODEL=6581\n";
            }
            elsif ($SIDChip == 2) {
                $textToCopy .= "SIDMODEL=8580\n";
            }
            elsif ($SIDChip == 3) {
                $textToCopy .= "SIDMODEL=ANY\n";
            }

            my $start;
            my $length;

            $start = $SIDfield{'startPage'};
            $start =~ s/^\$//;

            $length = $SIDfield{'pageLength'};
            $length =~ s/^\$//;

            $textToCopy .= "RELOC=$start,$length\n";
        }

        if ($isWindows) {
            Win32::Clipboard::Set($textToCopy);
        }
        else {
            $window->clipboardAppend(-type => 'STRING', '--', $textToCopy);
        }

        $STATUS = "SID header was copied to the clipboard INFO style.";
        return;
    }

    if (($copy{'filename'}) or ($CopyHow eq 'all')) {
        if ($isWindows) {
            $textToCopy .= "FILENAME: $drive$directory" . $separator . "$filename\n";
        }
        else {
            $textToCopy .= "FILENAME: $directory" . $separator . "$filename\n";
        }
    }
    $textToCopy .= "FILESIZE: $filesize\n" if (($copy{'filesize'}) or ($CopyHow eq 'all'));
    $textToCopy .= "MD5: $SIDMD5\n" if (($copy{'MD5'}) or ($CopyHow eq 'all'));

    foreach $field (@SIDfields) {
        # Not these.
        next if ($field eq 'data');
        next if (($CopyHow eq 'selected') and !($copy{$field}));

        if ($SIDfield{'version'} == 1) {
            # Not these fields. Not for version 1.
            next if (grep(/^$field$/, @v2Fields));
        }

        $textToCopy .= "$field: $SIDfield{$field}\n" if (($copy{$field}) or ($CopyHow eq 'all'));
    }

    if ($isWindows) {
        Win32::Clipboard::Set($textToCopy);
    }
    else {
        $window->clipboardAppend(-type => 'STRING', '--', $textToCopy);
    }

    if ($CopyHow eq 'selected') {
        $STATUS = "Selected fields of the SID header were copied to the clipboard.";
    }
    else {
        $STATUS = "All fields of the SID header were copied to the clipboard.";
    }
}

sub PasteFromClipboard {
    my $pastetext;
    my @pastetext;
    my $field;
    my $mymodified = 0;

    if ($isWindows) {
        $pastetext = Win32::Clipboard::GetText();
    }
    else {
        # Why the hell clipboardGet() doesn't work is beyond me.
        $pastetext = $window->SelectionGet(-selection => 'CLIPBOARD', -type => 'STRING');
    }

    @pastetext = split ("\n", $pastetext);

    foreach (@pastetext) {
        if (/^\s*FILENAME\s*[:=]\s*(.*)$/i) {
            next if ($PasteSelectedOnly and !$copy{'filename'});
            $filename = $1;
            # Remove path.
            $filename =~ s/^\S+[\/\\](\S+\.sid)$/$1/;
            $mymodified = 1;
        }

        # Special INFO fields.
        elsif (/^\s*SONGS\s*=\s*(.*)$/i) {
            my $songs;
            my $startSong;

            ($songs, $startSong) = split (/\s*,\s*/,$1);
            $startSong = 1 unless ($startSong);
            $mymodified = 1;

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'songs'})) {
                $SIDfield{'songs'} = $songs;
            }

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'startSong'})) {
                $SIDfield{'startSong'} = $startSong;
            }
        }
        elsif (/^\s*ADDRESS\s*=\s*(.*)$/) {
            my $loadAddress;
            my $initAddress;
            my $playAddress;

            ($loadAddress, $initAddress, $playAddress) = split (/\s*,\s*/,$1);
            $mymodified = 1;

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'loadAddress'})) {
                $SIDfield{'loadAddress'} = '$' . $loadAddress;
            }

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'initAddress'})) {
                $SIDfield{'initAddress'} = '$' . $initAddress;
            }

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'playAddress'})) {
                $SIDfield{'playAddress'} = '$' . $playAddress;
            }
        }
        elsif (/^\s*SPEED\s*=\s*(.*)$/i) {
            next if ($PasteSelectedOnly and !$copy{'speed'});
            $SIDfield{'speed'} = '0x' . $1;
            $mymodified = 1;
        }
        elsif (/^\s*SIDSONG\s*=\s*(.*)$/i) {
            next if ($SIDfield{'version'} != 2 and grep(/^flags$/, @v2Fields));
            next if ($PasteSelectedOnly and !$copy{'flags'});

            $mymodified = 1;
            $SIDfield{'flags'} = HexValue($SIDfield{'flags'}, 4);

            if ($1 =~ /YES/i) {
                $SIDfield{'flags'} |= (1 << $MUSPLAYER_OFFSET);
            }
            elsif ($1 =~ /NO/i) {
                $SIDfield{'flags'} &= ((~1) << $MUSPLAYER_OFFSET);
            }

            $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});
        }
        elsif (/^\s*COMPATIBILITY\s*=\s*(.*)$/i) {
            next if ($SIDfield{'version'} != 2 and grep(/^flags$/, @v2Fields));
            next if ($PasteSelectedOnly and !$copy{'flags'});

            $mymodified = 1;
            $SIDfield{'flags'} = HexValue($SIDfield{'flags'}, 4);

            if ($1 =~ /PSID/i) {
                $SIDfield{'flags'} |= (1 << $PLAYSID_OFFSET);
                $SIDfield{'magicID'} = 'PSID';
            }
            elsif ($1 =~ /BASIC/i) {
                $SIDfield{'flags'} |= (1 << $C64BASIC_OFFSET);
                $SIDfield{'magicID'} = 'RSID';
                $SIDfield{'initAddress'} = '$0000';
            }
            else {
                $SIDfield{'flags'} &= (~(1 << $PLAYSID_OFFSET));
                if ($1 =~ /R64/i) {
                    $SIDfield{'magicID'} = 'RSID';
                }
                else {
                    $SIDfield{'magicID'} = 'PSID';
                }
            }

            $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});
        }
        elsif (/^\s*CLOCK\s*=\s*(.*)$/i) {
            next if ($SIDfield{'version'} != 2 and grep(/^flags$/, @v2Fields));
            next if ($PasteSelectedOnly and !$copy{'flags'});

            $mymodified = 1;
            $SIDfield{'flags'} = HexValue($SIDfield{'flags'}, 4);

            if ($1 =~ /UNKNOWN/i) {
                $SIDfield{'flags'} &= ~(3 << $VIDEO_OFFSET);
            }
            elsif ($1 =~ /PAL/i) {
                $SIDfield{'flags'} &= ~(3 << $VIDEO_OFFSET);
                $SIDfield{'flags'} |= (1 << $VIDEO_OFFSET);
            }
            elsif ($1 =~ /NTSC/i) {
                $SIDfield{'flags'} &= ~(3 << $VIDEO_OFFSET);
                $SIDfield{'flags'} |= (2 << $VIDEO_OFFSET);
            }
            else {
                $SIDfield{'flags'} |= (3 << $VIDEO_OFFSET);
            }

            $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});
        }
        elsif (/^\s*SIDMODEL\s*=\s*(.*)$/i) {
            next if ($SIDfield{'version'} != 2 and grep(/^flags$/, @v2Fields));
            next if ($PasteSelectedOnly and !$copy{'flags'});

            $mymodified = 1;
            $SIDfield{'flags'} = HexValue($SIDfield{'flags'}, 4);

            if ($1 =~ /UNKNOWN/i) {
                $SIDfield{'flags'} &= ~(3 << $SIDCHIP_OFFSET);
            }
            elsif ($1 =~ /6581/i) {
                $SIDfield{'flags'} &= ~(3 << $SIDCHIP_OFFSET);
                $SIDfield{'flags'} |= (1 << $SIDCHIP_OFFSET);
            }
            elsif ($1 =~ /8580/i) {
                $SIDfield{'flags'} &= ~(3 << $SIDCHIP_OFFSET);
                $SIDfield{'flags'} |= (2 << $SIDCHIP_OFFSET);
            }
            else {
                $SIDfield{'flags'} |= (3 << $SIDCHIP_OFFSET);
            }

            $SIDfield{'flags'} = sprintf("0x%04X", $SIDfield{'flags'});
        }
        elsif (/^\s*RELOC\s*=\s*(.*)$/i) {
            my $start;
            my $length;

            ($start, $length) = split (/\s*,\s*/,$1);
            $mymodified = 1;

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'startPage'})) {
                $SIDfield{'startPage'} = '$' . $start;
            }

            if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{'pageLength'})) {
                $SIDfield{'pageLength'} = '$' . $length;
            }
        }

        # Everything else.
        else {
            foreach $field (@SIDfields) {
                next if ($SIDfield{'version'} != 2 and grep(/^$field$/, @v2Fields));

                if (/^\s*($field)\s*[:=]\s*(.*)$/i) {
                    if (!$PasteSelectedOnly or ($PasteSelectedOnly and $copy{$field})) {
                        $SIDfield{$field} = $2;
                        $mymodified = 1;
                    }
                }
            }
        }
    }

    if ($mymodified) {

        FieldsNotValid();
        CheckVersion();

        $modified = 1;

        if ($PasteSelectedOnly) {
            $STATUS = "Data were copied from the clipboard to the selected SID fields.";
        }
        else {
            $STATUS = "SID fields were pasted from the clipboard.";
        }
        UpdateFlags();
    }
}

##############################################################################
#
# Save/Load/Change settings
#
##############################################################################

my $ApplyButton;

sub EnableApplyButton {
    $ApplyButton->configure(-state => 'normal');
}

my $tempCopyHow;
my $tempPasteSelectedOnly;
my $tempSaveSettingsOnExit;
my $tempListSIDFiles;
my $tempListDataFiles;
my $tempListInfoFiles;
my $tempListAllFiles;	# XXX added
my $tempConfirmSave;
my $tempConfirmDelete;
my $tempSaveV2Only;
my $tempDefaultDirectory;
my $tempSaveDirectory;
my $tempHVSCDirectory;
my $tempAlwaysGoToSaveDir;
my $tempSIDPlayer;
my $tempSIDPlayerOptions;
my $tempHexEditor;
my $tempHexEditorOptions;
my $tempShowAllFields;
my $tempDisplayDataAs;
my $tempDisplayDataFrom;
my $tempShowColors;
my $tempAutoHVSCFilename;

sub ApplySettings {
    $CopyHow = $tempCopyHow;
    $PasteSelectedOnly = $tempPasteSelectedOnly;
    $SaveSettingsOnExit = $tempSaveSettingsOnExit;
    $ListSIDFiles = $tempListSIDFiles;
    $ListDataFiles = $tempListDataFiles;
    $ListInfoFiles = $tempListInfoFiles;
    $ListAllFiles = $tempListAllFiles;	# XXX
    $ConfirmSave = $tempConfirmSave;
    $ConfirmDelete = $tempConfirmDelete;
    $SaveV2Only = $tempSaveV2Only;
    $DefaultDirectory = $tempDefaultDirectory;
    $SaveDirectory = $tempSaveDirectory;
    $HVSCDirectory = $tempHVSCDirectory;
    $AlwaysGoToSaveDir = $tempAlwaysGoToSaveDir;
    $SIDPlayer = $tempSIDPlayer;
    $SIDPlayerOptions = $tempSIDPlayerOptions;
    $HexEditor = $tempHexEditor;
    $HexEditorOptions = $tempHexEditorOptions;
    $ShowAllFields = $tempShowAllFields;
    $DisplayDataAs = $tempDisplayDataAs;
    $DisplayDataFrom = $tempDisplayDataFrom;
    $ShowColors = $tempShowColors;
    $AutoHVSCFilename = $tempAutoHVSCFilename;

    $ApplyButton->configure(-state => 'disabled');
    $mySID->alwaysValidateWrite($SaveV2Only);
    ShowFields(0);
    ScanDir(1);
}

# First param: which page to raise (copy, file, tool, disp, none).
sub Settings {
    my ($raisePage) = @_;
    my $dialog;
    my $topframe;
    my $bottomframe;
    my $buttonPressed;
    my $tabs;
    my $copyPage;
    my $toolPage;
    my $dispPage;
    my $filePage;
    my $tempwidget;
    my $frame;
    my $subframe;
    my $tooltip;
    my $entry;
    my $row;

    $tempCopyHow = $CopyHow;
    $tempPasteSelectedOnly = $PasteSelectedOnly;
    $tempSaveSettingsOnExit = $SaveSettingsOnExit;
    $tempListSIDFiles = $ListSIDFiles;
    $tempListDataFiles = $ListDataFiles;
    $tempListInfoFiles = $ListInfoFiles;
    $tempListAllFiles = $ListAllFiles;	# XXX
    $tempConfirmSave = $ConfirmSave;
    $tempConfirmDelete = $ConfirmDelete;
    $tempSaveV2Only = $SaveV2Only;
    $tempDefaultDirectory = $DefaultDirectory;
    $tempSaveDirectory = $SaveDirectory;
    $tempHVSCDirectory = $HVSCDirectory;
    $tempAlwaysGoToSaveDir = $AlwaysGoToSaveDir;
    $tempSIDPlayer = $SIDPlayer;
    $tempSIDPlayerOptions = $SIDPlayerOptions;
    $tempHexEditor = $HexEditor;
    $tempHexEditorOptions = $HexEditorOptions;
    $tempShowAllFields = $ShowAllFields;
    $tempDisplayDataAs = $DisplayDataAs;
    $tempDisplayDataFrom = $DisplayDataFrom;
    $tempShowColors = $ShowColors;
    $tempAutoHVSCFilename = $AutoHVSCFilename;

    $dialog = $window->Toplevel();
    $dialog->transient($window);
    $dialog->withdraw();

    $dialog->title("SIDedit - Configure settings");

    $topframe = $dialog->Frame()
        ->pack(@topPack, @bothFill);

    $tabs = $topframe->NoteBook()
        ->pack(@topPack, @bothFill);

    $copyPage = $tabs->add('copy', -label => 'General', -anchor => 'nw', -underline => 0);
    $filePage = $tabs->add('file', -label => 'File navigator', -anchor => 'nw', -underline => 0);
    $toolPage = $tabs->add('tool', -label => 'Tools',   -anchor => 'nw', -underline => 0);
    $dispPage = $tabs->add('disp', -label => 'Display', -anchor => 'nw', -underline => 0);

    #####
    #
    # General tab
    #
    #####

    $frame = $copyPage->LabFrame(-label => "Clipboard",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $subframe = $frame->Frame()
        ->pack(@topPack, @bothFill);
    $subframe->Label(-text => 'Copy:')
        ->pack(@leftPack);

    $subframe->Radiobutton(@noBorder,
        -text => "Selected fields only",
        -variable => \$tempCopyHow,
        -value => 'selected',
        -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);
    $subframe->Radiobutton(@noBorder,
        -text => "All fields",
        -variable => \$tempCopyHow,
        -value => 'all',
        -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);
    $tempwidget = $subframe->Radiobutton(@noBorder,
        -text => "SIDPlay INFO style (*)",
        -variable => \$tempCopyHow,
        -value => 'info_style',
        -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);

    $subframe = $frame->Frame()
        ->pack(@topPack, @bothFill);
    $subframe->Label(-text => '(*) Header info copied INFO style can be saved directly into an old-style SIDplay INFO file.')
        ->pack(@leftPack);

    $subframe = $frame->Frame()
        ->pack(@topPack, @bothFill);
    $subframe->Checkbutton(@noBorder,
            -text => "Paste to selected fields only",
            -variable => \$tempPasteSelectedOnly,
            -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);

    $frame = $copyPage->LabFrame(-label => "Settings",
        -labelside => "acrosstop")
        ->pack(@topPack, @xFill);

    $frame->Checkbutton(@noBorder,
            -text => "Always save settings on exit",
            -variable => \$tempSaveSettingsOnExit,
            -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);
    $frame->Button(-text => 'Save settings now', -command => sub {ApplySettings(); SaveSettings();}, -underline => 11)
        ->pack(@leftPack, -padx => 5);

    #####
    #
    # File navigator tab
    #
    #####

    $frame = $filePage->LabFrame(-label => "File listing",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $frame->Checkbutton(@noBorder,
            -text => "List SID files",
            -variable => \$tempListSIDFiles,
            -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);
    $frame->Checkbutton(@noBorder,
            -text => "List C64 data files",
            -variable => \$tempListDataFiles,
            -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);
    $frame->Checkbutton(@noBorder,
            -text => "List INFO files",
            -variable => \$tempListInfoFiles,
            -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);
    $frame->Checkbutton(@noBorder,				# XXX
            -text => "List all files",
            -variable => \$tempListAllFiles,
            -command => sub {EnableApplyButton();} )
        ->pack(@leftPack);

    $frame = $filePage->LabFrame(-label => "File operations",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);
    $subframe = $frame->Frame()
        ->pack(@leftPack, @bothFill);

    $row = 0;

    $subframe->Checkbutton(@noBorder,
            -text => "Confirm save",
            -variable => \$tempConfirmSave,
            -command => sub {EnableApplyButton();} )
        ->grid(-column => 0, -row => $row, -sticky => 'w');
    $subframe->Checkbutton(@noBorder,
            -text => "Confirm delete",
            -variable => \$tempConfirmDelete,
            -command => sub {EnableApplyButton();} )
        ->grid(-column => 1, -row => $row, -sticky => 'w');
    $subframe->Checkbutton(@noBorder,
            -text => "Always save as PSID v2NG/RSID",
            -variable => \$tempSaveV2Only,
            -command => sub {EnableApplyButton();} )
        ->grid(-column => 2, -row => $row, -sticky => 'w');

    $row++;

    $subframe->Checkbutton(@noBorder,
            -text => "Automatically create HVSC compliant filename when 'name' field changes",
            -variable => \$tempAutoHVSCFilename,
            -command => sub {EnableApplyButton();} )
        ->grid(-column => 0, -columnspan => 3, -row => $row, -sticky => 'w');

    $frame = $filePage->LabFrame(-label => "Directory shortcuts",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $row = 0;

    $frame->Label(-text => "Default (home) directory:")
        ->grid(-column => 0, -row => $row, -sticky => 'w');
#    $entry = $frame->PathEntry(-textvariable => \$tempDefaultDirectory,
#        -initialdir => $tempDefaultDirectory,
#        -width => 30,
#        -selectcmd => sub {$tempDefaultDirectory .= $separator; $tempDefaultDirectory =~ s~/~\\~g if ($isWindows);})
#        ->grid(-column => 1, -row => $row, -sticky => 'w');
    $entry = $frame->Entry(-textvariable => \$tempDefaultDirectory, -width => 30)
        ->grid(-column => 1, -row => $row, -sticky => 'w');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<FocusOut>", sub {
        $tempDefaultDirectory .= $separator if ($tempDefaultDirectory !~ /\Q$separator\E$/);
        $tempDefaultDirectory =~ s~/~\\~g if ($isWindows);
    });
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    $frame->Button(-text => 'Use current',
        -command => sub { $tempDefaultDirectory = cwd; $tempDefaultDirectory .= $separator; $tempDefaultDirectory =~ s~/~\\~g if ($isWindows); EnableApplyButton(); } )
        ->grid(-column => 2, -row => $row, -sticky => 'w', -padx => 5);

    # Unfortunately, DirTree doesn't work very well under Windows.
    # Wait for chooseDirectory to arrive.
    if (!$isWindows) {
        $frame->Button(-text => 'Browse',
            -command => sub { if (DirTreeDialog($dialog, \$tempDefaultDirectory)) { EnableApplyButton();} } )
        ->grid(-column => 3, -row => $row, -sticky => 'w', -padx => 5);
    }

    $row++;

    $frame->Label(-text => "Default save directory:")
        ->grid(-column => 0, -row => $row, -sticky => 'w');
#    $entry = $frame->PathEntry(-textvariable => \$tempSaveDirectory,
#        -initialdir => $tempSaveDirectory,
#        -width => 30,
#        -selectcmd => sub {$tempSaveDirectory .= $separator; $tempSaveDirectory =~ s~/~\\~g if ($isWindows);})
#        ->grid(-column => 1, -row => $row, -sticky => 'w');
    $entry = $frame->Entry(-textvariable => \$tempSaveDirectory, -width => 30)
        ->grid(-column => 1, -row => $row, -sticky => 'w');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<FocusOut>", sub {
        $tempSaveDirectory .= $separator if ($tempSaveDirectory !~ /\Q$separator\E$/);
        $tempSaveDirectory =~ s~/~\\~g if ($isWindows);
    });
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    $frame->Button(-text => 'Use current',
        -command => sub { $tempSaveDirectory = cwd; $tempSaveDirectory .= $separator; $tempSaveDirectory =~ s~/~\\~g if ($isWindows); EnableApplyButton(); } )
        ->grid(-column => 2, -row => $row, -sticky => 'w', -padx => 5);

    # Unfortunately, DirTree doesn't work very well under Windows.
    # Wait for chooseDirectory to arrive.
    if (!$isWindows) {
        $frame->Button(-text => 'Browse',
            -command => sub { if (DirTreeDialog($dialog, \$tempSaveDirectory)) { EnableApplyButton();} } )
            ->grid(-column => 3, -row => $row, -sticky => 'w', -padx => 5);
    }

    $row++;

    $frame->Checkbutton(@noBorder,
            -text => "Always go to this save directory when doing 'Save as...'",
            -variable => \$tempAlwaysGoToSaveDir)
        ->grid(-column => 1, -columnspan => 3, -row => $row, -sticky => 'w');

    $row++;

    $frame->Label(-text => "HVSC directory:")
        ->grid(-column => 0, -row => $row, -sticky => 'w');
#    $entry = $frame->PathEntry(-textvariable => \$tempHVSCDirectory,
#        -initialdir => $tempHVSCDirectory,
#        -width => 30,
#        -selectcmd => sub {$tempHVSCDirectory .= $separator; $tempHVSCDirectory =~ s~/~\\~g if ($isWindows);})
#        ->grid(-column => 1, -row => $row, -sticky => 'w');
    $entry = $frame->Entry(-textvariable => \$tempHVSCDirectory, -width => 30)
        ->grid(-column => 1, -row => $row, -sticky => 'w');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<FocusOut>", sub {
        $tempHVSCDirectory .= $separator if ($tempHVSCDirectory !~ /\Q$separator\E$/);
        $tempHVSCDirectory =~ s~/~\\~g if ($isWindows);
    });
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    $frame->Button(-text => 'Use current',
        -command => sub { $tempHVSCDirectory = cwd; $tempHVSCDirectory .= $separator; $tempHVSCDirectory =~ s~/~\\~g if ($isWindows); EnableApplyButton(); } )
        ->grid(-column => 2, -row => $row, -sticky => 'w', -padx => 5);

    # Unfortunately, DirTree doesn't work very well under Windows.
    # Wait for chooseDirectory to arrive.
    if (!$isWindows) {
        $frame->Button(-text => 'Browse',
            -command => sub { if (DirTreeDialog($dialog, \$tempHVSCDirectory)) { EnableApplyButton();} } )
            ->grid(-column => 3, -row => $row, -sticky => 'w', -padx => 5);
    }

    #####
    #
    # Tools tab
    #
    #####

    $frame = $toolPage->LabFrame(-label => "Location of tools",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill, @expand);

    $subframe = $frame->LabFrame(-label => "SID player",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $row = 0;

    $subframe->Label(-text => "Full path to SID player:")
        ->grid(-column => 0, -row => $row, -sticky => 'e');
#    $entry = $subframe->PathEntry(-textvariable => \$tempSIDPlayer,
#        -width => 40,
#        -selectcmd => sub {$tempSIDPlayer =~ s~/~\\~g if ($isWindows);})
#        ->grid(-column => 1, -row => $row, -sticky => 'w');
    $entry = $subframe->Entry(-textvariable => \$tempSIDPlayer, -width => 40)
        ->grid(-column => 1, -row => $row, -sticky => 'w');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<FocusOut>", sub {
        $tempSIDPlayer =~ s~/~\\~g if ($isWindows);
    });
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    $subframe->Button(-text => 'Browse',
        -command => sub { ChooseExecutable(\$tempSIDPlayer, $dialog, "Choose SID Player"); $tempSIDPlayer =~ s~/~\\~g if ($isWindows); EnableApplyButton(); })
        ->grid(-column => 2, -row => $row, -sticky => 'w', -padx => 5, -pady => 5);

    $row++;

    $subframe->Label(-text => "Command line options:")
        ->grid(-column => 0, -row => $row, -sticky => 'e');
    $entry = $subframe->Entry(-textvariable => \$tempSIDPlayerOptions, -width => 20)
        ->grid(-column => 1, -columnspan => 2, -row => $row, -sticky => 'ew');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    $subframe = $frame->LabFrame(-label => "Hex editor",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $row = 0;

    $subframe->Label(-text => "Full path to hex editor:")
        ->grid(-column => 0, -row => $row, -sticky => 'e');
#    $entry = $subframe->PathEntry(-textvariable => \$tempHexEditor,
#        -width => 40,
#        -selectcmd => sub {$tempHexEditor =~ s~/~\\~g if ($isWindows);})
#        ->grid(-column => 1, -row => $row, -sticky => 'w');
    $entry = $subframe->Entry(-textvariable => \$tempHexEditor, -width => 40)
        ->grid(-column => 1, -row => $row, -sticky => 'w');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<FocusOut>", sub {
        $tempHexEditor =~ s~/~\\~g if ($isWindows);
    });
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    $subframe->Button(-text => 'Browse',
        -command => sub { ChooseExecutable(\$tempHexEditor, $dialog, "Choose hex editor"); $tempHexEditor =~ s~/~\\~g if ($isWindows); EnableApplyButton(); })
        ->grid(-column => 2, -row => $row, -sticky => 'w', -padx => 5, -pady => 5);

    $row++;

    $subframe->Label(-text => "Command line options:")
        ->grid(-column => 0, -row => $row, -sticky => 'e');
    $entry = $subframe->Entry(-textvariable => \$tempHexEditorOptions, -width => 20)
        ->grid(-column => 1, -columnspan => 2, -row => $row, -sticky => 'ew');

    $entry->bind("<Control-Key>", sub {} );
    $entry->bind("<Alt-Key>", sub {} );
    $entry->bind("<Delete>", sub {EnableApplyButton(); } );
    $entry->bind("<BackSpace>", sub {EnableApplyButton(); } );
    $entry->bind("<Key>", [sub {
            my $unused = shift;
            my $key = shift;

            # Mark it modified only when a non-modifier key was pressed.
            EnableApplyButton() if (($key =~ /^[\S]$/) or ($key =~ /^space$/i));
        }, Ev('K')] );

    #####
    #
    # Display tab
    #
    #####

    $frame = $dispPage->LabFrame(-label => "Main window display",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $row = 0;

    $frame->Checkbutton(@noBorder,
            -text => "Show all fields in main window",
            -variable => \$tempShowAllFields,
            -command => sub {EnableApplyButton(); } )
        ->pack(@leftPack);

    $subframe = $dispPage->LabFrame(-label => "SID data display",
        -labelside => "acrosstop")
        ->pack(@topPack, @bothFill);

    $subframe = $subframe->Frame()
        ->pack(@topPack, @bothFill);

    $subframe = $subframe->Frame()
        ->pack(@leftPack, @bothFill);

    $subframe->Checkbutton(@noBorder,
            -text => "Syntax coloring (if turned off, speeds up display and clipboard operations)",
            -variable => \$tempShowColors,
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 0, -columnspan => 2, -row => $row++, -sticky => 'w');

    $subframe->Label(-text => 'Display SID data as:')
        ->grid(-column => 0, -row => $row++, -sticky => 'w');

    $subframe->Radiobutton(@noBorder,
            -text => "Hex dump",
            -variable => \$tempDisplayDataAs,
            -value => 'hex',
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $subframe->Radiobutton(@noBorder,
            -text => "Assembly",
            -variable => \$tempDisplayDataAs,
            -value => 'assembly',
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 0, -row => $row++, -sticky => 'w');
    $subframe->Radiobutton(@noBorder,
            -text => "Assembly with illegal instructions",
            -justify => 'left',
            -variable => \$tempDisplayDataAs,
            -value => 'assembly_illegal',
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 0, -row => $row++, -sticky => 'w');

    $row = 1;

    $subframe->Label(-text => 'Display SID data starting from:')
        ->grid(-column => 1, -row => $row++, -sticky => 'w');

    $subframe->Radiobutton(@noBorder,
            -text => "Load address",
            -variable => \$tempDisplayDataFrom,
            -value => 'loadAddress',
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 1, -row => $row++, -sticky => 'w');
    $subframe->Radiobutton(@noBorder,
            -text => "Init address",
            -variable => \$tempDisplayDataFrom,
            -value => 'initAddress',
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 1, -row => $row++, -sticky => 'w');
    $subframe->Radiobutton(@noBorder,
            -text => "Play address",
            -variable => \$tempDisplayDataFrom,
            -value => 'playAddress',
            -command => sub {EnableApplyButton(); } )
        ->grid(-column => 1, -row => $row++, -sticky => 'w');

    #####
    #
    # Buttons below.
    #
    #####

    $bottomframe = $dialog->Frame()
        ->pack(@bottomPack, @bothFill, -pady => 10);
    $bottomframe->Button(-text => 'Cancel', -underline => 0, -width => 10,
            -command => sub { $buttonPressed = 0; } )
        ->pack(@rightPack, -padx => 5);
    $ApplyButton = $bottomframe->Button(-text => 'Apply', -underline => 0, -width => 10, -state => 'disabled',
            -command => sub { ApplySettings(); } )
        ->pack(@rightPack, -padx => 5);
    $bottomframe->Button(-text => 'OK', -underline => 0, -width => 10,
            -command => sub { $buttonPressed = 1; } )
        ->pack(@rightPack, -padx => 5);

    $tabs->raise($raisePage) if ($raisePage ne 'none');

    $dialog->resizable(0,0);

    $dialog->Popup();
    $dialog->grab();

    $dialog->focus();
    $dialog->raise();
    $dialog->waitVariable(\$buttonPressed);
    $dialog->grabRelease();
    $dialog->withdraw();

    ApplySettings() if ($buttonPressed);
}

# First param: optional, TRUE if confirmation pop-up should be shown.
sub SaveSettings {
    my ($showConfirmBox) = @_;
    my @SelectedFields;
    my $SelectedFields;
    my $counter = 0;

    unless (open (INI, "> $SIDEDIT_INI")) {
        # Die quietly.
        return;
    }

    foreach (keys %copy) {
        push(@SelectedFields, $_) if ($copy{$_});
    }
    $SelectedFields = join(',',@SelectedFields);

    $MainWindowGeometry = $window->geometry();

    print INI <<EOF;
[SIDedit]
SaveSettingsOnExit  = $SaveSettingsOnExit
CopyToClipboard     = $CopyHow
SelectedFields      = $SelectedFields
PasteSelectedOnly   = $PasteSelectedOnly
ShowAllFields       = $ShowAllFields
ShowTextBoxGeometry = $ShowTextBoxGeometry
MainWindowGeometry  = $MainWindowGeometry
ShowSIDDataGeometry = $ShowSIDDataGeometry

[FileNavigator]
ListSIDFiles        = $ListSIDFiles
ListDataFiles       = $ListDataFiles
ListInfoFiles       = $ListInfoFiles
ListAllFiles        = $ListAllFiles
ConfirmSave         = $ConfirmSave
ConfirmDelete       = $ConfirmDelete
AlwaysSaveAsV2NG    = $SaveV2Only
AutoHVSCFilename    = $AutoHVSCFilename
DefaultDirectory    = $DefaultDirectory
SaveDirectory       = $SaveDirectory
HVSCDirectory       = $HVSCDirectory
AlwaysGoToSaveDir   = $AlwaysGoToSaveDir

[DataDisplay]
DisplayDataAs       = $DisplayDataAs
DisplayDataFrom     = $DisplayDataFrom
SaveDataAs          = $SaveDataAs
ShowColors          = $ShowColors

[Tools]
SIDPlayer           = $SIDPlayer
SIDPlayerOptions    = $SIDPlayerOptions
HexEditor           = $HexEditor
HexEditorOptions    = $HexEditorOptions
EOF

    foreach (@ToolList) {
        print INI "ExternalTool$counter       = $_\n";
        $counter++;
    }

    close(INI);

    if ($showConfirmBox) {
        ErrorBox("Settings were saved to $SIDEDIT_INI.", "Settings are saved");
    }

    $STATUS = "Settings were saved to $SIDEDIT_INI.";
}

sub LoadSettings {
    my $keyword;
    my $value;
    my $inifilename;
    my @SelectedFields;

    unless (open (INI, "< $SIDEDIT_INI")) {
        # Do nothing, defaults will be set.
        return;
    }

    while (<INI>) {
        if (/^\s*\[SIDedit\]\s*$/) {
            # Found our section.
            while (<INI>) {
                next if (/^\s*$/); # Skip empty lines.
                next if (/^\s*[;#]/); # Skip comments.

                if (/^\s*(\S+)\s*=\s*(.*)\s*$/) {
                    $keyword = $1;
                    $value = $2;

                    if ($keyword eq 'SaveSettingsOnExit') {
                        $SaveSettingsOnExit = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'ConfirmSave') {
                        $ConfirmSave = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'ConfirmDelete') {
                        $ConfirmDelete = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'AlwaysSaveAsV2NG') {
                        $SaveV2Only = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'AutoHVSCFilename') {
                        $AutoHVSCFilename = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'CopyToClipboard') {
                        if (grep(/^$value$/, qw(selected all info_style))) {
                            $CopyHow = $value;
                        }
                    }
                    elsif ($keyword eq 'PasteSelectedOnly') {
                        $PasteSelectedOnly = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'SelectedFields') {
                        @SelectedFields = split(/\s*,\s*/, $value);

                        foreach (keys %copy) {
                            $copy{$_} = 0;
                        }

                        foreach (@SelectedFields) {
                            if (exists($copy{$_})) {
                                $copy{$_} = 1;
                            }
                        }
                    }
                    elsif ($keyword eq 'SIDPlayer') {
                        $SIDPlayer = $value;
                    }
                    elsif ($keyword eq 'SIDPlayerOptions') {
                        $SIDPlayerOptions = $value;
                    }
                    elsif ($keyword eq 'HexEditor') {
                        $HexEditor = $value;
                    }
                    elsif ($keyword eq 'HexEditorOptions') {
                        $HexEditorOptions = $value;
                    }
                    elsif ($keyword eq 'ListSIDFiles') {
                        $ListSIDFiles = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'ListDataFiles') {
                        $ListDataFiles = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'ListInfoFiles') {
                        $ListInfoFiles = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'ListAllFiles') {	# XXX
                        $ListAllFiles = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif (($keyword eq 'DefaultDirectory') and ($value)) {
                        $DefaultDirectory = $value;

                        # We have to change to the dir.
                        if (chdir($value)) {
                            $directory = cwd;
                            GetDriveAndDir() if ($isWindows);
                        }
                    }
                    elsif (($keyword eq 'SaveDirectory') and ($value)) {
                        $SaveDirectory = $value;
                    }
                    elsif (($keyword eq 'HVSCDirectory') and ($value)) {
                        $HVSCDirectory = $value;
                    }
                    elsif ($keyword eq 'AlwaysGoToSaveDir') {
                        $AlwaysGoToSaveDir = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'ShowAllFields') {
                        $ShowAllFields = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                    elsif ($keyword eq 'DisplayDataAs') {
                        $DisplayDataAs = 'hex' if ($value =~ /hex/i);
                        $DisplayDataAs = 'assembly' if ($value =~ /^assembly$/i);
                        $DisplayDataAs = 'assembly_illegal' if ($value =~ /illegal/i);
                    }
                    elsif ($keyword eq 'DisplayDataFrom') {
                        $DisplayDataFrom = 'loadAddress' if ($value =~ /loadAddress/i);
                        $DisplayDataFrom = 'initAddress' if ($value =~ /initAddress/i);
                        $DisplayDataFrom = 'playAddress' if ($value =~ /playAddress/i);
                        $DisplayDataFrom = 'other'       if ($value =~ /other/i);
                    }
                    elsif ($keyword eq 'SaveDataAs') {
                        $SaveDataAs = 'binary' if ($value =~ /binary/i);
                        $SaveDataAs = 'ascii' if ($value =~ /ascii/i);
                        $SaveDataAs = 'image' if ($value =~ /image/i);
                    }
                    elsif ($keyword =~ /^ExternalTool(\d+)/) {
                        $ToolList[$1] = $value;
                    }
                    elsif ($keyword eq 'ShowTextBoxGeometry') {
                        $ShowTextBoxGeometry = $value;
                    }
                    elsif ($keyword eq 'MainWindowGeometry') {
                        $MainWindowGeometry = $value;
                    }
                    elsif ($keyword eq 'ShowSIDDataGeometry') {
                        $ShowSIDDataGeometry = $value;
                    }
                    elsif ($keyword eq 'ShowColors') {
                        $ShowColors = (($value eq '1') or ($value =~ /^yes$/i)) ? 1 : 0;
                    }
                }
            }
        }
    }

    close (INI);
}

##############################################################################
#
# Bindings
#
##############################################################################

sub Quit {
    unless (SaveChanges()) {
        $MainWindowGeometry = $window->geometry();
        SaveSettings(0) if ($SaveSettingsOnExit);
        $window->destroy();
        exit;
    }
}

sub SetupBindings {

    # File listbox

    # A single-click selects the file.
    $filelistbox->bind("<ButtonRelease-1>", \&FileSelect);

    # Alphanumerical keypress cycles through files starting with that letter.
    $filelistbox->bind("<KeyPress>", [\&FileSelect, Ev('A')]);

    # Home and End.
    $filelistbox->bind("<Home>", sub {
        $filelistbox->activate(0);
        $filelistbox->see(0);
        $filelistbox->selectionClear(0, 'end');
        $filelistbox->selectionSet(0);
        FileSelect();
    });
    $filelistbox->bind("<End>", sub {
        $filelistbox->activate('end');
        $filelistbox->see('end');
        $filelistbox->selectionClear(0, 'end');
        $filelistbox->selectionSet('end');
        FileSelect();
    });

    # Double-click launches SID player.
    $filelistbox->bind("<Double-Button-1>", sub {LaunchApp('SID player');});

    $filelistbox->bind("<Delete>", sub {Delete();});

    # Dir listbox

    # Double-click or simple return changes to dir.
    $dirlistbox->bind("<Double-Button-1>", [\&DirSelect, '=CHDIR']);
    $dirlistbox->bind("<Return>", [\&DirSelect, '=CHDIR']);

    # Home and End.
    $dirlistbox->bind("<Home>", sub {
        $dirlistbox->activate(0);
        $dirlistbox->see(0);
        $dirlistbox->selectionClear(0, 'end');
        $dirlistbox->selectionSet(0);
    });
    $dirlistbox->bind("<End>", sub {
        $dirlistbox->activate('end');
        $dirlistbox->see('end');
        $dirlistbox->selectionClear(0, 'end');
        $dirlistbox->selectionSet('end');
    });

    # Alphanumerical keypress cycles through dirs starting with that letter.
    $dirlistbox->bind("<KeyPress>", [\&DirSelect, Ev('A')]);

    $dirlistbox->bind("<Delete>", [\&DeleteDir]);

    # User entered a specific directory name.
#    $direntry->bind("<FocusOut>", sub {ChangeToDir($directory);} );
    $direntry->bind("<Return>", sub {ChangeToDir($directory);} );

    # For some stupid reason clicking in a listbox doesn't
    # make it focused, so we fix it here.
    $filelistbox->bind("<Button-1>", sub {$filelistbox->focus();} );
    $dirlistbox->bind("<Button-1>", sub {$dirlistbox->focus();} );

    # Move over these listboxes to make them focused.
    $filelistbox->bind("<Enter>", sub {$filelistbox->focus();} );
    $dirlistbox->bind("<Enter>", sub {$dirlistbox->focus();} );

    # Global bindings for some shortcuts.

    $window->bind("<Control-s>", [\&Save, 1]);
    $window->bind("<Control-a>", [\&SaveAs, 0]);

    $window->bind("<Control-l>", \&Delete);

    $window->bind("<Control-n>", \&NewFile);

    $window->bind("<<Copy>>", \&CopyToClipboard);
    $window->bind("<<Paste>>", \&PasteFromClipboard);
    $window->bind("<Control-c>", \&CopyToClipboard);
    $window->bind("<Control-Insert>", \&CopyToClipboard);
    $window->bind("<Control-v>", \&PasteFromClipboard);
    $window->bind("<Shift-Insert>", \&PasteFromClipboard);
    $window->bind("<Alt-c>", \&CopyToClipboard);
    $window->bind("<Alt-p>", \&PasteFromClipboard);

    # Handler for closing window.
    $window->protocol('WM_DELETE_WINDOW', \&Quit);

    $window->bind("<Alt-q>", \&Quit);
    $window->bind("<Control-q>", \&Quit);
    $window->bind("<Escape>", \&Quit);

    $window->bind("<Control-r>", \&MakeDir);
    $window->bind("<Control-e>", \&DeleteDir);

    $window->bind("<Shift-Home>", sub {ChangeToDir($DefaultDirectory);});
    $window->bind("<Control-Home>", sub {ChangeToDir($SaveDirectory);});
    $window->bind("<Alt-Home>", sub {ChangeToDir($HVSCDirectory);});

    $window->bind("<Control-h>", \&HVSCLongFilename);

    $window->bind("<Control-p>", sub {LaunchApp('SID player');});
    $window->bind("<Alt-x>", sub {LaunchApp('hex editor');});
    $window->bind("<Control-x>", sub {LaunchApp('hex editor');});

    $window->bind("<Control-t>", \&RunTool);
    $window->bind("<Control-o>", \&ShowLastToolOutput);

    $window->bind("<Control-s>", \&ShowFields);

    $window->bind("<Control-b>", \&EditSpeed);
    $window->bind("<Control-f>", \&EditFlags);

    $window->bind("<Control-d>", \&ShowSIDData);

    $window->bind("<Control-g>", \&Settings);

    $window->bind("<F1>", \&ShowHelp);

    # Some basic high-level tabbing order is specified here.
    $direntry->bind("<Tab>", sub {$dirlistbox->focus(); Tk->break();} );
    $dirlistbox->bind("<Tab>", sub {$filelistbox->focus(); Tk->break();} );
    $dirlistbox->bind("<Shift-Tab>", sub {$direntry->focus(); Tk->break();} );
    $filelistbox->bind("<Tab>", sub {$filenameentry->focus(); Tk->break();} );
    $filelistbox->bind("<Shift-Tab>", sub {$dirlistbox->focus(); Tk->break();} );
    $filenameentry->bind("<Shift-Tab>", sub {$filelistbox->focus(); Tk->break();} );
}

##############################################################################
#
# MAIN
#
##############################################################################

my $startdir;

# Determines the full pathname where the SIDedit documentation file, the
# SID file format description and the INI file are or should be.
if (dirname($0) eq '.') {
    $startdir = cwd . $separator;
}
else {
    $startdir = dirname($0) . $separator;
}

$SID_FORMAT = $startdir . $SID_FORMAT;
$SIDEDIT_POD = $startdir . $SIDEDIT_POD;
$SIDEDIT_INI = $startdir . $SIDEDIT_INI;

LoadSettings();

$mySID->alwaysValidateWrite($SaveV2Only);

$window = new MainWindow();
$window->withdraw();

$window->title("SIDedit v$VERSION");
$window->Pixmap("SIDedit_icon", -data => $SIDeditIconString);
$window->Pixmap("HVSC_icon", -data => $HVSCIconString);
$window->iconimage("SIDedit_icon");

# Unfortunately, we need to do this embedding for Perl2EXE.
# The ToolBar warning (if any) can be safely ignored.
foreach (@toolbaricons) {
    chomp;

    my ($n, $d) = (split /:/)[0, 4];
    $window->Photo($n, -data => $d);
}

# $window->setPalette("wheat"); # RGB: 245 222 149

BuildWindow($window);

$DISABLED_ENTRY_COLOR = $window->cget('background');
$DISABLED_ENTRY_COLOR = 'grey' unless (defined($DISABLED_ENTRY_COLOR));	#XXX

my $geometry = $window->geometry();

($MINWIDTH, $MINHEIGHT) = ($geometry =~ /^(\d+)x(\d+)/);
$window->minsize($MINWIDTH, $MINHEIGHT);

$window->geometry($MainWindowGeometry) if ($MainWindowGeometry);

ScanDir(1);
ShowFields(0);

$window->deiconify();
MainLoop();
