package Library::News;

require v5.6.0;
use strict;
use warnings;
use XML::DT;
use Library::MLang;

require Exporter;

# Module Stuff
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(&new &load &shell_add_new &news2Html &showForm &setLanguage &languages);

# Version
our $VERSION = '0.05';

# Multi-Language Stuff
our $lang;

$INC{'Library/News.pm'} =~ m{/News\.pm$};
$lang = loadMLangFile("$`/News.lang");
$lang->setLanguage('pt');

sub new {
  my $file = shift or die("File name not specified");
  open XML, ">$file" or die "Cannot open that file!";
  print XML $lang->str("<[novidades]>\n</[novidades]>\n");
  close XML;
  my $self = { file => $file };
  return bless($self);
}

sub load {
  my $file = shift;
  $lang->setLanguage(shift);
  my $self = {};
  my ($data,$url,$texto,$titulo);
  my %h = (
	   '-outputenc' => 'ISO-8859-1',
	   '-inputenc'  => 'ISO-8859-1',
	   '-default'   => sub{toxml},
	   $lang->get('novidades') => sub{},
	   $lang->get('novidade')  => sub{
	     $self->{news}->{$data}->{titulo}=$titulo if defined($titulo);
	     $self->{news}->{$data}->{url}   =$url    if defined($url);
	     $self->{news}->{$data}->{texto} =$texto  if defined($texto);
	     undef($titulo);
	     undef($url);
	     undef($data);
	     undef($texto);
	   },
	   $lang->get('titulo')    => sub{ $titulo = $c; },
	   $lang->get('data')      => sub{
	     my @data;
	     if ($c=~m{^(....)[-/.](..)[-/.](..)$}) {
	       @data = ($1,$2,$3);
	     } elsif ($c=~m{^(..)[-/.](..)[./-](....)$}) {
	       @data = ($3,$2,$1);
	     } else {
	       die "File has errors on date: $c";
	     }
	     $data = join "",@data;
	   },
	   $lang->get('texto')     => sub{ $texto = $c; },
	   $lang->get('url')       => sub{ $url = $c; },
	  );
  dt($file,%h);
  $self->{file} = $file;
  return bless($self);
}

sub languages {
  return $lang->languages();
}

sub setLanguage {
  $lang->setLanguage(shift);
}

sub shell_add_new {
  my $file = shift;
  my $news = load $file, shift;
  $news->shell_add;
  $news->save;
}

sub shell_add {
  my $self = shift;
  my ($bool,$op,$texto,$data,$titulo,$url,$corpo);

  do {
    print $lang->str("> [data] ([formatodata]): ");
    $data = <>;

    print $lang->str("> [titulo]: ");
    $titulo = <>;
    chomp($titulo);

    print $lang->str("> [url]: ");
    $url = <>;
    chomp($url);

    print $lang->str("> [texto]: ([pracabar])\n");
    $corpo = "";
    $corpo .= $_  while (($_=<>)!~/^\s*$/);

    $data = checkDate($data);

    ($bool, $texto) = makeXML($data,$titulo,$url,$corpo);

    print "\n\n --->>>\n\n$texto\n\n <<<---\n\n";
    if (!$bool) {
      print $lang->str("[erro]\n");
      return;
    }

    do {
      print $lang->get('confirma');
      chomp($op = <>);
    } while ($op ne $lang->get('sim') && $op ne $lang->get('nao'));
  } while ($op ne $lang->get('sim'));

  $self->{news}->{$data}->{titulo} = $titulo;
  $self->{news}->{$data}->{url}    = $url;
  $self->{news}->{$data}->{texto}  = $corpo;
}

# makeXML
#
# Parameteres should be the date, title, url and body of the new
# (in this order). The function tests for XML correctness and
# returns and array with a bool (the correctness value) and a
# string with the new XML
#
sub makeXML {
  my $data   = $lang->str("  <[data]>")   .shift().$lang->str("</[data]>\n");
  my $titulo = $lang->str("  <[titulo]>") .shift().$lang->str("</[titulo]>\n");
  my $url    = $lang->str("  <[url]>")    .shift().$lang->str("</[url]>\n");
  my $corpo  = $lang->str("  <[texto]>\n").shift().$lang->str("  </[texto]>\n");

  my $novidade=$lang->str("  <[novidade]>\n$data$titulo$url$corpo </[novidade]>\n");

  if (xmlTestString($novidade)) {
    return (1, $novidade);
  } else {
    return (0, $novidade);
  }
}

# checkDate
#
# Gets a date for arguments in the usual YYYY-MM-DD or DD-MM-YYYY
# or DD-MM-YY or YY-MM-DD and returns a date in the correct form
# to be used in the news file
#
sub checkDate {
  my $data = shift;
  my $mes;
  my $ano;
  my $dia;

  ## Tratar a data
  $data =~ m!^(\d\d?(?:\d\d)?)[-/.](\d\d?)[-/.](\d\d?(?:\d\d)?)$!;

  if ($1>31) {
    $ano = $1; $mes = $2; $dia = $3;
  } else {
    $ano = $3; $mes = $2; $dia = $1;
  }

  if ($ano>50 && $ano<100) {
    $ano = 1900+$ano;
  }
  if ($ano<50) {
    $ano = 2000+$ano;
  }

  $mes = ($mes<10)?"0$mes":"$mes" unless($mes=~/^0/);
  $dia = ($dia<10)?"0$dia":"$dia" unless($dia=~/^0/);

  $data = "$ano$mes$dia";

  return $data;
}

# xmlTestString
#
# The argument should be a XML string for a simple new. It returns
# a boolean true if the XML is 'correct' accordingly with the DTD
# in the documentation
#
sub xmlTestString {
  my $string = shift;
  my $zbr = eval {dtstring($string,getNewsHandlerChecker())};
  if ($zbr) {
    $string = join "*", (split //, $zbr);
    return eval($string);
  } else {
    return 0;
  }
}

# getNewsHandlerChecker
#
# Returns a XML::DT handler to check the correctness of a new XML
#
sub getNewsHandlerChecker {
  return (
	  '-outputenc' => 'ISO-8859-1',
	  '-inputenc'  => 'ISO-8859-1',
	  '-default'   => sub{"0"},
	  '-pcdata'    => sub{"1"},
	  $lang->get('novidade') => sub{"$c"},
	  $lang->get('titulo')   => sub{if (inctxt($lang->get('novidade')))    {$c} else {"0"}},
	  $lang->get('url')      => sub{if (inctxt($lang->get('novidade')))    {$c} else {"0"}},
	  $lang->get('data')     => sub{if (inctxt($lang->get('novidade')))    {$c} else {"0"}},
	  $lang->get('texto')    => sub{if (inctxt($lang->get('novidade')))    {$c} else {"0"}},
	  'em'                   => sub{if (inctxt($lang->str("[texto]|li|p"))) {$c} else {"0"}},
	  'ol'                   => sub{if (inctxt($lang->str("[texto]|li|p"))) {$c} else {"0"}},
	  'ul'                   => sub{if (inctxt($lang->str("[texto]|li|p"))) {$c} else {"0"}},
	  'a'                    => sub{if (inctxt($lang->str("[texto]|li|p"))) {
	    (defined($v{href}))?$c:"0" } else {"0"}},
	  'img'                  => sub{if (inctxt($lang->str("[texto]|li|p"))) {
	    (defined($v{src}) and defined($v{alt}))?$c:"0" } else {"0"}},
	  'p'                    => sub{if (inctxt($lang->str("li|[texto]")))  {$c} else {"0"}},
	  'li'                   => sub{if (inctxt('ol|ul'))                   {$c} else {"0"}},

	 );
}

sub save {
  my $self = shift;
  open F, ">$self->{file}" or die ("Cannot save file!");
  print F $lang->str("<[novidades]>\n");
  for (sort keys %{$self->{news}}) {
    print F $lang->str(" <[novidade]>\n");

    print F $lang->str("  <[data]>");
    print F join("-",(/^(....)(..)(..)$/));
    print F $lang->str("</[data]>\n");

    print F $lang->str("  <[titulo]>");
    print F $self->{news}->{$_}->{titulo};
    print F $lang->str("</[titulo]>\n");

    print F $lang->str("  <[url]>");
    print F $self->{news}->{$_}->{url};
    print F $lang->str("</[url]>\n");

    print F $lang->str("  <[texto]>\n");
    print F $self->{news}->{$_}->{texto};
    print F $lang->str("  </[texto]>\n");

    print F $lang->str(" </[novidade]>\n");
  }
  print F $lang->str("</[novidades]>\n");
  close F;
}

# showForm
#
# For use in webservers
# The file and a reference to the args hash table
#
sub showForm {

  my $file = shift;
  my $ref = shift;
  my %ARGS = %{$ref};

  my $form;

  if (%ARGS) {
    my $url = $ARGS{'url'};
    my $data = $ARGS{'data'};
    my $corpo = $ARGS{'corpo'};
    my $titulo = $ARGS{'titulo'};
    my $bool;
    my $texto;
    my $level = $ARGS{'level'} || 0;

    $data = checkDate($data);
    ($bool, $texto) = makeXML($data,$titulo,$url,$corpo);

    if ($level) {

      my $news;
      if ($ARGS{language}) {
	$news = load($file,$ARGS{language});
      } else {
	$news = load $file;
      }
      $news->{news}->{$data}->{titulo} = $titulo;
      $news->{news}->{$data}->{url}    = $url;
      $news->{news}->{$data}->{texto}  = $corpo;

      $news->save;

      $form = "<center>\n";
      $form.= $lang->str("<br><br><br><h2>[fim]</h2><br><br>");
      $form.= "</center>\n";

    } else {
      $data =~ /^(....)(..)(..)$/;
      $data = "$1-$2-$3";
      if ($bool) {
	my $output = "<dl><dt><tt>$data</tt></dt><dd><a href=\"$url\">$titulo</a><p>$corpo</p></dd></dl>";

	$form = "<center>\n";
	$form.= "<table \n";
	$form.= "       style='border: solid; border-width: 1; padding: 10;'>\n";
	$form.= "  <form method='POST' enctype='application/x-www-form-urlencoded'>\n";
	$form.= " <tr><td colspan='2'>\n";
	$form.= "     <input type='hidden' name='data' value='$data'>\n";
	$form.= "     <input type='hidden' name='titulo' value='$titulo'>\n";
	$form.= "     <input type='hidden' name='url' value='$url'>\n";
	$form.= "     <input type='hidden' name='corpo' value='$corpo'>\n";
	$form.= "     <input type='hidden' name='level' value='1'>\n";
	$form.= " <div style='border: solid; border-width: 1; padding: 10;'>\n";
	$form.= "  $output ";
	$form.= " </div> ";
	$form.= " </td></tr>\n";
	$form.= $lang->str(" <tr><td><b>[confirma]</b></td><td align='right'>\n");
	$form.= $lang->str(" <input type='submit' value='  [ok]  '></td></tr>\n");

	$form.= "<tr><td colspan='2'><br><br></td></tr>\n";

	$form.= "</form><form method='POST' enctype='application/x-www-form-urlencoded'>\n";

	$form.= $lang->str(" <tr><td><b>[data]:</b></td>\n");
	$form.= "     <td><input name='data' value='$data'></td></tr>\n";
	$form.= $lang->str(" <tr><td><b>[titulo]:</b></td>\n");
	$form.= "     <td><input name='titulo' size='60' value='$titulo'>";
	$form.= "      </td></tr>\n";
	$form.= $lang->str(" <tr><td><b>[url]:</b></td>\n");
	$form.= "     <td><input name='url' size='60' value='$url'>";
	$form.= "      </td></tr>\n";
	$form.= $lang->str(" <tr><td valign='top'><b>[texto]:</b></td>\n");
	$form.= "   <td><textarea name='corpo' rows='10' ";
	$form.= "        cols='70'>$corpo</textarea>\n";
	$form.= "     </td></tr>\n";
	$form.= $lang->str(" <tr><td><b>[corrigir]</b></td><td align='right'>\n");
	$form.= $lang->str("<input type='submit' value='  [ok]  '></td></tr>\n");
	$form.= "</table></form>";
	$form.= "</center>";
      } else {
	$form = "<center><form method='POST' enctype='application/x-www-form-urlencoded'><table \n";
	$form.= "       style='border: solid; border-width: 1; padding: 10;'>\n";
	$form.= " <tr><td colspan='2' align='center'>";
	$form.= $lang->str("  <b>[erro]</b></td></td>\n");
	$form.= $lang->str(" <tr><td><b>[data]:</b></td>\n");
	$form.= "     <td><input name='data' value='$data'></td></tr>\n";
	$form.= $lang->str(" <tr><td><b>[titulo]:</b></td>\n");
	$form.= "     <td><input name='titulo' size='60' value='$titulo'>";
	$form.= "      </td></tr>\n";
	$form.= $lang->str(" <tr><td><b>[url]:</b></td>\n");
	$form.= "     <td><input name='url' size='60' type='file' value='$url'>";
	$form.= "      </td></tr>\n";
	$form.= $lang->str(" <tr><td valign='top'><b>[texto]:</b></td>\n");
	$form.= "   <td><textarea name='corpo' rows='10' ";
	$form.= "        cols='70'>$corpo</textarea>\n";
	$form.= "     </td></tr>\n";
	$form.= " <tr><td></td><td align='right'>\n";
	$form.= $lang->str(" <input type='submit' value='  [ok]  '></td></tr>\n");
	$form.= "</table></form>";
	$form.= "</center>";
      }
    }
  } else {
    my $ano;
    my $mes;
    my $dia;
    chomp($ano = `date +%Y`);
    chomp($mes = `date +%m`);
    chomp($dia = `date +%d`);

    $form = "<center>\n";
    $form.= "<form method='POST' enctype='application/x-www-form-urlencoded'><table \n";
    $form.= "         style='border: solid; border-width: 1; padding: 10;'>\n";
    $form.= $lang->str(" <tr><td><b>[data]:</b></td>\n");
    $form.= "     <td><input name='data' value='$dia-$mes-$ano'></td></tr>\n";
    $form.= $lang->str(" <tr><td><b>[titulo]:</b></td>\n");
    $form.= "     <td><input name='titulo' size='60'></td></tr>\n";
    $form.= $lang->str(" <tr><td><b>[url]:</b></td>\n");
    $form.= "     <td><input name='url' size='60'></td></tr>\n";
    $form.= $lang->str(" <tr><td valign='top'><b>[texto]:</b></td>\n");
    $form.= "   <td><textarea name='corpo' rows='10' cols='70'></textarea>\n";
    $form.= "     </td></tr>\n";
    $form.= " <tr><td></td><td align='right'>\n";
    $form.= $lang->str(" <input type='submit' value='  [ok]  '></td></tr>\n");
    $form.= "</table></form>";
    $form.= "</center>";
  }
  return $form;
}

# news2Html
#
# This function receives a number 'n' and a news filename. It returns a string
# with the n most recent news in HTML format.
#
sub news2Html {
  my $file = shift;
  my $number = shift;
  my $news = load ($file,shift);

  my $text = "<dl>";
  my $count = 1;
  for (reverse sort keys %{$news->{news}}) {
    last if ($count>$number && $number>0);
    ++$count;
    /^(....)(..)(..)$/;
    $text.= "<dt><tt>$1-$2-$3</tt></dt>\n";
    $text.= "<dd><a href=\"$news->{news}->{$_}->{url}\">";
    $text.= "$news->{news}->{$_}->{titulo}</a>";
    $text.= "<p>$news->{news}->{$_}->{texto}</p>";
    $text.= "</dd>";
  }
  $text.= "</dl>";
}

1;
__END__

=head1 NAME

Library::News - Perl extension for managing an XML news file

=head1 SYNOPSIS

  use Library::News;

  shell_add_new("news.xml");

  news2Html("news.xml", 4);

  showForm("news.xml", \%ARGS);

  setLanguage("pt");

  @languages = languages();

=head1 DESCRIPTION

The News module aims to help web masters designing and managing web
sites news in an easy way. The news module provides three
functions. Two of them provide managing features (adding a new) and
the other provides an easy way for printing the new.

Note that the news XML file should not be edited manually.

There is a project to make an object oriented API for using this
module but is not yet full implemented.

=head2 languages

This function returns an array with the possible languages to use.
When choosing a language with the setLanguage function, you must
enter a code equal to on returned by this function.

=head2 setLanguage

This function sets the language to be used. To know what language
to use, call the last function and print the elements of the array.

By default, it is used portuguese (pt).

You must not use this module in different languages over the same
file.

=head2 shell_add_new

This function is designed to be used in the shell. You can have a
program named C<add_new>, written in Perl like

  #!/usr/bin/perl

  my $filename = shift;
  shell_add_new($filename);

for adding news to some file. So, you can call it using

  add_new news.xml

and the program will prompt for all the data it needs. If you have
only a file, you can replace the line

  my $filename = shift;

with something like

  my $filename = "news.xml";

The second argument to C<shell_add_new> is not needed but can be used: the
name of the language to use.

=head2 news2Html

This is a pretty printer for the news xml file. You should supply the
news XML filename and a number 'n'. The function returns a string with
the most recent 'n' news formatted in HTML for direct use in a CGI. If
'n' is C<-1>, then, news2Html returns all news converted to HTML.

The third argument, if supplied, changes the language used to parse the
XML file.

=head2 showForm

This function was designed to be used on CGI. Most web designers have
to maintain ways of updating information by thirty part persons. So,
it can create a web CGI to add news.

The way is calling showForm with the news XML filename and a reference
to an hash with the CGI parameters and printing the resulting string.
showForm returns HTML for a form asking for the news
information. Then, it calls itself to check the correctness of the new
XML. If the XML is not correct, it asks for the user correct it. If
the XML is correct, it asks if the user wants to continue. If yes, it
updates the news XML file.

If using the CGI module you can convert the param() function to an
hash using:

  @keys = param();
  foreach $key (@keys) {
    $args{$key} = param($key);
  }
  showForm("news.xml",\%args);

You can change the language to use in the C<%args> array. For example, use:

  $args{language}='uk'


=head1 DTD

Using english:

  <!ENTITY % xhtml-subset "(#PCDATA|em|ol|ul|a|img)" >

  <!ELEMENT news (new+) >
  <!ELEMENT new (date, title, url?, text) >
  <!ELEMENT date #PCDATA>
  <!ELEMENT title #PCDATA>
  <!ELEMENT url #PCDATA>
  <!ELEMENT a #PCDATA>
     <!ATTLIST a href CDATA #REQUIRED>
  <!ELEMENT text (%xhtml-subset;|p)+>
  <!ELEMENT p (%xhtml-subset;) >
  <!ELEMENT em (#PCDATA) >
  <!ELEMENT ol (li+) >
  <!ELEMENT ul (li+) >
  <!ELEMENT li (%xhtml-subset;|p)>
  <!ELEMENT img EMPTY>
     <!ATTLIST img src CDATA #REQUIRED
                   alt CDATA #REQUIRED>

Using portuguese:

  <!ENTITY % xhtml-subset "(#PCDATA|em|ol|ul|a|img)" >

  <!ELEMENT novidades (novidade+) >
  <!ELEMENT novidade (date, titulo, url?, texto) >
  <!ELEMENT data #PCDATA>
  <!ELEMENT titulo #PCDATA>
  <!ELEMENT url #PCDATA>
  <!ELEMENT a #PCDATA>
     <!ATTLIST a href CDATA #REQUIRED>
  <!ELEMENT texto (%xhtml-subset;|p)+>
  <!ELEMENT p (%xhtml-subset;) >
  <!ELEMENT em (#PCDATA) >
  <!ELEMENT ol (li+) >
  <!ELEMENT ul (li+) > 
  <!ELEMENT li (%xhtml-subset;|p)>
  <!ELEMENT img EMPTY>
     <!ATTLIST img src CDATA #REQUIRED
                   alt CDATA #REQUIRED>

Other languages can be added using the C<News.lang> file in the C<lib>
directory.

=head1 AUTHOR

Alberto M. B. Simões, <albie@alfarrabio.um.geira.pt>

=head1 SEE ALSO

Manpages CGI(3), perl(1).

=cut
