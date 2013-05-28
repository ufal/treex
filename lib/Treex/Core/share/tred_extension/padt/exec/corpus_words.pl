#!/usr/bin/perl -w ###################################################################### 2009/08/12
#
# corpus_words.pl ###################################################################### Otakar Smrz

# $Id: corpus_words.pl 4947 2012-10-16 21:49:02Z smrz $

use strict;

use XML::Twig;

use Encode;

use File::Basename;


$/ = undef;

our $data;


while (my $text = decode "utf8", <>) {

    $data = {};

    if ($text =~ /^\s*</ and $text =~ />\s*$/ and $ARGV !~ /\.txt$/) {

        read_data_xml($text);
    }
    else {

        read_data_txt($text);
    }

    open X, '>', $ARGV . '.words.pml';

    select X;

    my $meta = "    " . '<revision>$' . 'Revision: ' . '$</revision>' . "\n" .
               "    " . '<date>$' . 'Date: ' . '$</date>' . "\n" .
               "    " . '<document>' . $data->{'document'} . '</document>';

    print << "<?xml?>";
<?xml version="1.0" encoding="utf-8"?>
<PADT-Words xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
  <head>
    <schema href="words.schema.xml" />
  </head>
  <meta>
$meta
  </meta>
  <data>
<?xml?>

    my @id = (0);

    foreach my $para (@{$data->{'para'}}) {

        warn "$ARGV\n\tIgnoring empty paragraph after index $id[0]\n" and next unless exists $para->{'form'} and exists $para->{'unit'};

        local $\ = "\n";

        $id[0]++;

        @id = @id[0 .. 0];

        printf '<Para id="w-p%d">', @id;
        print  '<form>' . $para->{'form'} . '</form>';
        print  '<with>';

        foreach my $unit (@{$para->{'unit'}}) {

            $id[1]++;

            @id = @id[0 .. 1];

            printf '<Unit id="w-p%du%d">', @id;
            print  '<form>' . (encode "utf8", join " ", split " ", $unit->{'form'}) . '</form>';
            print  '</Unit>';
        }

        print  '</with>';
        print  '</Para>';
    }

    print << "<?xml?>";
  </data>
</PADT-Words>
<?xml?>

    close X;
}


sub read_data_txt {

    my $text = $_[0];

    $text =~ s/\&/\&amp;/g;
    $text =~ s/\</\&lt;/g;
    $text =~ s/\>/\&gt;/g;

    $data->{'document'} = fileparse($ARGV, qr/\.[a-z]+/);

    $data->{'para'} = [ map {

                            { 'form' => 'TEXT', 'unit' => [ map { { 'form' => $_ } } split /\n/, $_ ] }

                        }

                        grep { /\S/ } split /\n([^\n\S]*\n)+/, $text ];
}


sub read_data_xml {

    my $text = $_[0];

    $text =~ s/(&HT;(\s*\x{0640}+)?)//g and warn "$ARGV\n\tDeleting $1\n";

    $text =~ s/(&[A-Z][A-Za-z0-9]+;)//g and warn "$ARGV\n\tDeleting $1\n";

    $text =~ s/ & //g and warn "$ARGV\n\tDeleting &\n";

    $text =~ /(&(?!amp;|lt;|gt;))/ and warn "$ARGV\n\tVerify $1\n";

    $text =~ s/<seg id=([0-9]+)>/<seg id="$1">/g;

    my $source = XML::Twig->new(

            'ignore_elts'   => {

                            'HEADER'    => 1,
                            'FOOTER'    => 1,

                               },

            'twig_roots'    => {

                            'DOC/DOCNO' => 1,

                            'HEADLINE'  => 1,
                            'hl'        => 1,

                            'DATELINE'  => 1,

                            'P'         => 1,
                            'p'         => 1,

                               },

            'twig_handlers' => {

                            'DOC/DOCNO' =>  \&parse_docno,

                            'HEADLINE'  =>  \&parse_headline,
                            'hl'        =>  \&parse_headline,

                            'DATELINE'  =>  \&parse_dateline,

                            'P/seg'     =>  \&parse_seg,
                            'p/seg'     =>  \&parse_seg,

                            'P'         =>  \&parse_p,
                            'p'         =>  \&parse_p,

                               },

            'start_tag_handlers'    => {

                            'DOC'       =>  \&setup_doc,

                            'P'         =>  \&setup_p,
                            'p'         =>  \&setup_p,

                                       },

            );

    $source->parse($text);

    $source->purge();
}


sub setup_doc {

    my ($twig, $elem) = @_;

    $data->{'document'} = $elem->att('docid') || $elem->att('id') || '';

    # $elem->att('type')
    # $elem->att('language')

    $data->{'para'} = [];
}


sub parse_docno {

    my ($twig, $elem) = @_;

    die "$ARGV\n\tConflicts in document identification $data->{'document'}\n" if exists $data->{'document'} and $data->{'document'} ne '';

    $data->{'document'} = $elem->text();
}


sub setup_p {

    my ($twig, $elem) = @_;

    push @{$data->{'para'}}, {} unless @{$data->{'para'}} and not keys %{$data->{'para'}[-1]};
}


sub parse_headline {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('HEADLINE', $text);
}


sub parse_dateline {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('DATELINE', $text);
}


sub parse_seg {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('TEXT', $text, 'units');
}


sub parse_p {

    my ($twig, $elem) = @_;

    die "$ARGV\n\tUnexpected structure of the document\n"  if grep { $_->name() eq 'seg' } $elem->children();

    my $text = $elem->text();

    $twig->purge();

    process_text('TEXT', $text) unless $text =~ /^\s*$/;
}


sub process_text {

    my ($meta, $text, $mode) = @_;

    push @{$data->{'para'}}, {} unless $mode or @{$data->{'para'}} and not keys %{$data->{'para'}[-1]};

    die "$ARGV\n\tUnexpected structure of the document\n"  if exists $data->{'para'}[-1]{'form'}
                                                                 and $data->{'para'}[-1]{'form'} ne ''
                                                                 and $data->{'para'}[-1]{'form'} ne $meta;

    $data->{'para'}[-1]{'form'} = $meta;

    $data->{'para'}[-1]{'unit'} = [] unless exists $data->{'para'}[-1]{'unit'};

    push @{$data->{'para'}[-1]{'unit'}}, { 'form' => $text };
}
