package Treex::Block::W2A::NL::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

# various abbreviations found as un-tokenized in the Alpino corpus
my $UNBREAKERS = qr{\p{Alpha}|\p{N}+|[IVXLCMDivxlcmd]+| # single letter, numerals    
    
    art|Ass|bijv|Burg|ca|Ch|Chr|co|Co|dec|dhr|dr|Dr|drs|Drs|ds|Ds|enz|etc|fa|Gebr|Gld|
    gr|ha|Heidemij|Inc|Int|ir|jhr|jl|jr|kath|Kon|lib|Mc|mej|mevr|mgr|Mij|
    min|mln|mr|Mr|Ned|nl|nom|nov|nr|Olie|pct|Penn|Ph|plm|pnt|prof|ptn|red|resp|
    sec|soc|Sr|St|tel|Th|Uitgeversmij|vacatureE|Ver|Wm|zg|zgn|Zn
}xi;

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;

    # preseve dots in abbreviations
    my $sent2 = $sentence;
    my $repls = 0; # count current number of replacements to compensate position (the replacement pattern is 8 chars longer)
    while ( $sentence =~ m/(?:^|\s)($UNBREAKERS)\.(?!\p{Alpha}|\p{N})/gi ) {
        my $unbr = $1;
        my $mp   = pos $sentence;

        if ( $unbr =~ m/\./ ) {
            $unbr =~ s/\./XXXDOTXXX/g;
            $sent2 = substr( $sent2, 0, $mp - length($unbr) - 1 + ($repls * 8) ) . $unbr . 'XXXDOTXXX' . substr( $sent2, $mp + ($repls * 8) );
        }
        else {
            $sent2 = substr( $sent2, 0, $mp - 1 + ($repls * 8) ) . 'XXXDOTXXX' . substr( $sent2, $mp + ($repls * 8) );
        }
        $repls++;
    }

    # preserve hyphens in coordinated compounds
    $sent2 =~ s/(\p{Alpha})-(\s)/$1XXXHYPHXXX$2/;
    $sent2 =~ s/(\s)-(\p{Alpha})/$1XXXHYPHXXX$2/;

    # preserve apostrophes in some constructions
    $sent2 =~ s/(^|\s)'([st])(\s|$)/$1XXXAPOXXX$2$3/;    # 's middags, 't meisje

    $sentence = $self->SUPER::tokenize_sentence($sent2);

    # get back the dots and hyphens
    $sentence =~ s/XXXDOTXXX/. /g;
    $sentence =~ s/XXXHYPHXXX/-/g;
    $sentence =~ s/XXXAPOXXX/'/g;

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;

    return $sentence;
};

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::NL::Tokenize - rule-based tokenization

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.

This class uses Dutch-specific regex rules for tokenization
of abbreviations, ordinal numbers and compounds connected by hyphens (hyphens
and dots will not be separated).

The output is suitable for Alpino.

The code is derived from the German tokenization block.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
