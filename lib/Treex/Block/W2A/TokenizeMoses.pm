package Treex::Block::W2A::TokenizeMoses;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TokenizeOnWhitespace';

use Treex::Core::Resource qw(require_file_from_share);

has '+language' => ( required => 1 );

has nonbreaking_prefixes_dir => ( is => 'ro', isa => 'Str', default => 'data/models/tokenizer' );
has nonbreaking_prefixes_file_stem => ( is => 'ro', isa => 'Str', default => 'nonbreaking_prefix' );
has nonbreaking_prefix => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

has protected_patterns_dir   => ( is => 'ro', isa => 'Str', default => 'data/models/tokenizer' );
has protected_patterns_file => ( is => 'rw', isa => 'Str', default => '' );
has protected_patterns => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

has aggressive => ( is => 'rw', isa => 'Bool', default => 0 );

has skip_xml => ( is => 'rw', isa => 'Bool', default => 0 );

has penn => ( is => 'rw', isa => 'Bool', default => 0 );

has no_escape => ( is => 'rw', isa => 'Bool', default => 0 );

sub process_start {
    my ($self) = @_;

    # load protected patterns
    if ($self->protected_patterns_file) {
        my $path = require_file_from_share($self->protected_patterns_dir
            . '/' . $self->protected_patterns_file,
            ref($self));
        open my $file, '<:utf8', $path;
        while (my $line = <$file>) {
            chomp $line;
            push @{$self->protected_patterns}, $line;
        }
        close $file;
    }

    # load the language-specific non-breaking prefix info from files in the nonbreaking_prefixes directory 
    {
        my $path = require_file_from_share( $self->nonbreaking_prefixes_dir
            . '/' . $self->nonbreaking_prefixes_file_stem
            . '.' . $self->language,
            ref($self));
        open my $file, '<:utf8', $path;
        while (my $item = <$file>) {
            chomp $item;
            if (($item) && (substr($item,0,1) ne "#")) {
                if ($item =~ /(.*)[\s]+(\#NUMERIC_ONLY\#)/) {
                    $self->nonbreaking_prefix->{$1} = 2;
                } else {
                    $self->nonbreaking_prefix->{$item} = 1;
                }
            }
        }
        close $file;
    }
}

# the actual tokenize function which tokenizes one input string
# input: one string
# return: the tokenized string for the input string
override 'tokenize_sentence' => sub {
    my ($self, $text) = @_;

    if (($self->skip_xml && $text =~ /^<.+>$/) || $text =~ /^\s*$/) {
        # don't try to tokenize XML/HTML tag lines
        return $text;
    }

    if ($self->penn) {
      return $self->tokenize_penn($text);
    }

    chomp($text);
    $text = " $text ";

    # remove ASCII junk
    $text =~ s/\s+/ /g;
    $text =~ s/[\000-\037]//g;

    # Find protected patterns
    my @protected = ();
    foreach my $protected_pattern (@{$self->protected_patterns}) {
      my $t = $text;
      while ($t =~ /($protected_pattern)(.*)$/) {
        push @protected, $1;
        $t = $2;
      }
    }

    for (my $i = 0; $i < scalar(@protected); ++$i) {
      my $subst = sprintf("THISISPROTECTED%.3d", $i);
      $text =~ s,\Q$protected[$i], $subst ,g;
    }
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    # seperate out all "other" special characters
    $text =~ s/([^\p{IsAlnum}\s\.\'\`\,\-])/ $1 /g;

    # aggressive hyphen splitting
    if ($self->aggressive)
    {
        $text =~ s/([\p{IsAlnum}])\-(?=[\p{IsAlnum}])/$1 \@-\@ /g;
    }

    #multi-dots stay together
    $text =~ s/\.([\.]+)/ DOTMULTI$1/g;
    while($text =~ /DOTMULTI\./)
    {
        $text =~ s/DOTMULTI\.([^\.])/DOTDOTMULTI $1/g;
        $text =~ s/DOTMULTI\./DOTDOTMULTI/g;
    }

    # seperate out "," except if within numbers (5,300)
    #$text =~ s/([^\p{IsN}])[,]([^\p{IsN}])/$1 , $2/g;

    # separate out "," except if within numbers (5,300)
    # previous "global" application skips some:  A,B,C,D,E > A , B,C , D,E
    # first application uses up B so rule can't see B,C
    # two-step version here may create extra spaces but these are removed later
    # will also space digit,letter or letter,digit forms (redundant with next section)
    $text =~ s/([^\p{IsN}])[,]/$1 , /g;
    $text =~ s/[,]([^\p{IsN}])/ , $1/g;

    # separate , pre and post number
    #$text =~ s/([\p{IsN}])[,]([^\p{IsN}])/$1 , $2/g;
    #$text =~ s/([^\p{IsN}])[,]([\p{IsN}])/$1 , $2/g;

    # turn `into '
    #$text =~ s/\`/\'/g;

    #turn '' into "
    #$text =~ s/\'\'/ \" /g;

    if ($self->language eq "en")
    {
        #split contractions right
        $text =~ s/([^\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([^\p{IsAlpha}\p{IsN}])[']([\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([\p{IsAlpha}])/$1 '$2/g;
        #special case for "1990's"
        $text =~ s/([\p{IsN}])[']([s])/$1 '$2/g;
    }
    elsif (($self->language eq "fr") or ($self->language eq "it") or ($self->language eq "ga"))
    {
        #split contractions left
        $text =~ s/([^\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([^\p{IsAlpha}])[']([\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([\p{IsAlpha}])/$1' $2/g;
    }
    else
    {
        $text =~ s/\'/ \' /g;
    }

    #word token method
    my @words = split(/\s/,$text);
    $text = "";
    for (my $i=0;$i<(scalar(@words));$i++)
    {
        my $word = $words[$i];
        if ( $word =~ /^(\S+)\.$/)
        {
            my $pre = $1;
            if (($pre =~ /\./ && $pre =~ /\p{IsAlpha}/) || ($self->nonbreaking_prefix->{$pre} && $self->nonbreaking_prefix->{$pre}==1) || ($i<scalar(@words)-1 && ($words[$i+1] =~ /^[\p{IsLower}]/)))
            {
                #no change
			}
            elsif (($self->nonbreaking_prefix->{$pre} && $self->nonbreaking_prefix->{$pre}==2) && ($i<scalar(@words)-1 && ($words[$i+1] =~ /^[0-9]+/)))
            {
                #no change
            }
            else
            {
                $word = $pre." .";
            }
        }
        $text .= $word." ";
    }

    # clean up extraneous spaces
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    # restore protected
    for (my $i = 0; $i < scalar(@protected); ++$i) {
      my $subst = sprintf("THISISPROTECTED%.3d", $i);
      $text =~ s/$subst/$protected[$i]/g;
    }

    #restore multi-dots
    while($text =~ /DOTDOTMULTI/)
    {
        $text =~ s/DOTDOTMULTI/DOTMULTI./g;
    }
    $text =~ s/DOTMULTI/./g;

    #ensure final line break
    $text .= "\n" unless $text =~ /\n$/;

    return $text;
};

sub tokenize_penn {
    # Improved compatibility with Penn Treebank tokenization.  Useful if
    # the text is to later be parsed with a PTB-trained parser.
    #
    # Adapted from Robert MacIntyre's sed script:
    #   http://www.cis.upenn.edu/~treebank/tokenizer.sed

    my ($self, $text) = @_;
    chomp($text);

    # remove ASCII junk
    $text =~ s/\s+/ /g;
    $text =~ s/[\000-\037]//g;

    # attempt to get correct directional quotes
    $text =~ s/^``/`` /g;
    $text =~ s/^"/`` /g;
    $text =~ s/^`([^`])/` $1/g;
    $text =~ s/^'/`  /g;
    $text =~ s/([ ([{<])"/$1 `` /g;
    $text =~ s/([ ([{<])``/$1 `` /g;
    $text =~ s/([ ([{<])`([^`])/$1 ` $2/g;
    $text =~ s/([ ([{<])'/$1 ` /g;
    # close quotes handled at end

    $text =~ s=\.\.\.= _ELLIPSIS_ =g;

    # separate out "," except if within numbers (5,300)
    $text =~ s/([^\p{IsN}])[,]([^\p{IsN}])/$1 , $2/g;
    # separate , pre and post number
    $text =~ s/([\p{IsN}])[,]([^\p{IsN}])/$1 , $2/g;
    $text =~ s/([^\p{IsN}])[,]([\p{IsN}])/$1 , $2/g;

    #$text =~ s=([;:@#\$%&\p{IsSc}])= $1 =g;
$text =~ s=([;:@#\$%&\p{IsSc}\p{IsSo}])= $1 =g;

    # Separate out intra-token slashes.  PTB tokenization doesn't do this, so
    # the tokens should be merged prior to parsing with a PTB-trained parser
    # (see syntax-hyphen-splitting.perl).
    $text =~ s/([\p{IsAlnum}])\/([\p{IsAlnum}])/$1 \@\/\@ $2/g;

    # Assume sentence tokenization has been done first, so split FINAL periods
    # only.
    $text =~ s=([^.])([.])([\]\)}>"']*) ?$=$1 $2$3 =g;
    # however, we may as well split ALL question marks and exclamation points,
    # since they shouldn't have the abbrev.-marker ambiguity problem
    $text =~ s=([?!])= $1 =g;

    # parentheses, brackets, etc.
    $text =~ s=([\]\[\(\){}<>])= $1 =g;
    $text =~ s/\(/-LRB-/g;
    $text =~ s/\)/-RRB-/g;
    $text =~ s/\[/-LSB-/g;
    $text =~ s/\]/-RSB-/g;
    $text =~ s/{/-LCB-/g;
    $text =~ s/}/-RCB-/g;

    $text =~ s=--= -- =g;

    # First off, add a space to the beginning and end of each line, to reduce
    # necessary number of regexps.
    $text =~ s=$= =;
    $text =~ s=^= =;

    $text =~ s="= '' =g;
    # possessive or close-single-quote
    $text =~ s=([^'])' =$1 ' =g;
    # as in it's, I'm, we'd
    $text =~ s='([sSmMdD]) = '$1 =g;
    $text =~ s='ll = 'll =g;
    $text =~ s='re = 're =g;
    $text =~ s='ve = 've =g;
    $text =~ s=n't = n't =g;
    $text =~ s='LL = 'LL =g;
    $text =~ s='RE = 'RE =g;
    $text =~ s='VE = 'VE =g;
    $text =~ s=N'T = N'T =g;

    $text =~ s= ([Cc])annot = $1an not =g;
    $text =~ s= ([Dd])'ye = $1' ye =g;
    $text =~ s= ([Gg])imme = $1im me =g;
    $text =~ s= ([Gg])onna = $1on na =g;
    $text =~ s= ([Gg])otta = $1ot ta =g;
    $text =~ s= ([Ll])emme = $1em me =g;
    $text =~ s= ([Mm])ore'n = $1ore 'n =g;
    $text =~ s= '([Tt])is = '$1 is =g;
    $text =~ s= '([Tt])was = '$1 was =g;
    $text =~ s= ([Ww])anna = $1an na =g;

    #word token method
    my @words = split(/\s/,$text);
    $text = "";
    for (my $i=0;$i<(scalar(@words));$i++)
    {
        my $word = $words[$i];
        if ( $word =~ /^(\S+)\.$/)
        {
            my $pre = $1;
            if (($pre =~ /\./ && $pre =~ /\p{IsAlpha}/) || ($self->nonbreaking_prefix->{$pre} && $self->nonbreaking_prefix->{$pre}==1) || ($i<scalar(@words)-1 && ($words[$i+1] =~ /^[\p{IsLower}]/)))
            {
                #no change
            }
            elsif (($self->nonbreaking_prefix->{$pre} && $self->nonbreaking_prefix->{$pre}==2) && ($i<scalar(@words)-1 && ($words[$i+1] =~ /^[0-9]+/)))
            {
                #no change
            }
            else
            {
                $word = $pre." .";
            }
        }
        $text .= $word." ";
    }

    # restore ellipses
    $text =~ s=_ELLIPSIS_=\.\.\.=g;

    # clean out extra spaces
    $text =~ s=  *= =g;
    $text =~ s=^ *==g;
    $text =~ s= *$==g;

    #ensure final line break
    $text .= "\n" unless $text =~ /\n$/;

    return $text;
}

# escape special chars
after 'process_zone' => sub {
    my ($self, $zone) = @_;

    # penn is always escaped
    # otherwise escape unless no_escape=1;
    # also if skip_xml, then skip XML/HTML tag lines
    if (($self->penn || !$self->no_escape) && (!$self->skip_xml || $zone->sentence !~ /^<.+>$/)) {
        my $aroot = $zone->get_atree();
        foreach my $anode ($aroot->get_descendants()) {
            my $text = $anode->form;

            $text =~ s/\&/\&amp;/g;   # escape escape
            $text =~ s/\|/\&#124;/g;  # factor separator
            $text =~ s/\</\&lt;/g;    # xml
            $text =~ s/\>/\&gt;/g;    # xml
            $text =~ s/\'/\&apos;/g;  # xml
            $text =~ s/\"/\&quot;/g;  # xml
            $text =~ s/\[/\&#91;/g;   # syntax non-terminal
            $text =~ s/\]/\&#93;/g;   # syntax non-terminal

            $anode->set_form($text);
        }
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TokenizeMoses - Moses tokenizer.

=head1 DESCRIPTION

Treex integration of the Moses tokenizer, simplified in some aspects.

Sample Tokenizer
Version 1.1
written by Pidong Wang, based on the code written by Josh Schroeder and Philipp Koehn
$Id: tokenizer.perl 915 2009-08-10 08:15:49Z philipp $

=head1 METHODS

=over

=item language

Required. Influences the nonbreaking prefixes file to be loaded.

=item nonbreaking_prefixes_file_stem = 'nonbreaking_prefix'

=item nonbreaking_prefixes_dir = 'data/models/tokenizer'

The nonbreaking prefixes file is loaded from C<nonbreaking_prefixes_dir/nonbreaking_prefixes_file_stem.language>

=item protected_patterns_file

=item protected_patterns_dir = 'data/models/tokenizer'

specify file with patters to be protected in tokenisation

=item aggressive

aggressive hyphen splitting

=item skip_xml

don't try to tokenize XML/HTML tag lines

=item penn

use Penn treebank-like tokenization

TODO: no_space_after is not fully trustworthy if C<penn=1> is set

=item no_escape

don't perform HTML escaping on apostrophy, quotes, etc

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Pidong Wang

Josh Schroeder

Philipp Koehn

=head1 COPYRIGHT AND LICENSE

This file is licensed under the GNU Lesser General Public License version 2.1 or, at your option, any later version.

