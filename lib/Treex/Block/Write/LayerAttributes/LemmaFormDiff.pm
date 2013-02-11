package Treex::Block::Write::LayerAttributes::LemmaFormDiff;
use Moose;
use Treex::Core::Common;

use String::Diff;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => (
    builder    => '_build_return_values_names',
    lazy_build => 1
);

has 'output_diff' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0
);

has 'split_parts' => (
    isa => enum( [ 'no', 'front', 'all' ] ),
    is => 'ro',
    default => 'no'
);

Readonly my $ESCAPE_SRC => [ '[',     ']',     '{',     '}' ];
Readonly my $ESCAPE_TGT => [ '-LBR-', '-RBR-', '-LBC-', '-RBC-' ];

Readonly my $IRREGULAR_LEMMAS => 'tentýž|všechen|on';

# Build default return values' suffixes for different settings of
# output_diff and split_parts
sub _build_return_values_names {
    my ($self) = @_;
    my @retvals;

    if ( $self->split_parts eq 'no' ) {
        push @retvals, '';
    }
    elsif ( $self->split_parts eq 'front' ) {
        push @retvals, '_back', '_front';
    }
    else {
        push @retvals, '_back', '_mid', '_front';
    }
    if ( $self->output_diff ) {
        push @retvals, '_diff';
    }
    return \@retvals;
}

# Escape brackets before diffing
sub escape {
    my ($str) = @_;
    for ( my $i = 0; $i < @{$ESCAPE_SRC}; ++$i ) {
        my $src = $ESCAPE_SRC->[$i];
        my $tgt = $ESCAPE_TGT->[$i];
        $str =~ s/\Q$src\E/$tgt/g;
    }
    return $str;
}

# Unescape previously escaped brackets
sub unescape {
    my ($str) = @_;
    for ( my $i = 0; $i < @{$ESCAPE_SRC}; ++$i ) {
        my $src = $ESCAPE_SRC->[$i];
        my $tgt = $ESCAPE_TGT->[$i];
        $str =~ s/\Q$tgt\E/$src/g;
    }
    return $str;
}

sub modify_single {

    my ( $self, $lemma, $form ) = @_;

    return undef if ( !defined($lemma) || !defined($form) );

    $lemma = escape( lc $lemma );
    $form  = escape( lc $form );

    my $diff = String::Diff::diff_merge(
        $lemma, $form,
        remove_open  => '`',
        remove_close => '\'',
        append_open  => '<',
        append_close => '>'
    );

    # fix diff problems
    # nej-, ne- at the beginning
    $diff =~ s/^<n>e<([^>]?)e>/<ne$1>e/;      # neexistuje, nejefektivnější
    $diff =~ s/^<ne>j<([^>]*)j>/<nej$1>j/;    # nejjistější, nejnejistější
    $diff =~ s/^n<(ej?)n>/<n$1>n/;            # nenáročný
    $diff =~ s/^ne<(j?)ne>/<ne$1>ne/;         # nejnestoudnější, nenechat

    # 'o', 'ou'
    $diff =~ s/'<([^>]+)>o`([^']+)'/o$2'<$1o>/;    # vzniklo, vyššího
    $diff =~ s/(?<=[^']){o}u(?=.)/`u'<ou>/;        # hlouběji
    $diff =~ s/<([^>]+)>o`ut'$/`out'<$1o>/;        # zapomněl

    # 't' infinitive -> imperative / 2nd pl.
    $diff =~ s/'<([^>]+)>t</t'<$1t/;                       # víte, máte
    $diff =~ s/([^'])<([^>]+)>t</$1`t'<$2t/;               # pojedete, zůstanete
    $diff =~ s/([^'])<([^>]+)>t`([^>]+)'</$1`t$3'<$2t/;    # chcete
    $diff =~ s/([^'>])`([^>]+)'t</$1`$2t'<t/;              # berte

    # 'í'
    $diff =~ s/<([^>]+)>í`([^']+)'<([^>]+)>$/`í$2'<$1í$3>/;    # nižšího
    $diff =~ s/<([^>]+)>í`([^']+)'$/`í$2'<$1í>/;               # mají, nižší
    $diff =~ s/(?<=[^'])<(ějš)>í$/`í'<ější>/;              # modernější
    $diff =~ s/`([^']+)'<(ějš)>í$/`$1í'<ější>/;            # pozdější
    $diff =~ s/(?<=[^'])<ějš>í<(.+)>$/`í'<ější$1>/;        # modernějších, modernějším
    $diff =~ s/`([^']+)'<ějš>í<(.+)>$/`$1í'<ější$2>/;      # pozdějších

    # infinitive 't'
    $diff =~ s/<(..)>([aei])`t'$/`$2t'<$1$2>/;                    # musíme, zaměstnána, umístěni
    $diff =~ s/`(.)'<(...?)>([aei])`t'$/`$1$3t'<$2$3>/;           # odsouzeni, vyhozeni
    $diff =~ s/`o'u`t'<(.+)>$/`out'<u$1>/;                        # vyplynulo

    # 'h'/'ch'
    $diff =~ s/<([^>]+)c>h`(.*)'$/`h$2'<$1ch>/;                           # dražších
    $diff =~ s/`([^']+)'<([^>]+)>h`([^']+)'<([^>]+)>$/`$1h$3'<$2h$4>/;    # delšího
    $diff =~ s/<([^>]+)>h`([^']+)'<([^>]+)>$/`h$2'<$1h$3>/;               # dražšího

    # 'um', 'em' -> '-em'
    $diff =~ s/<m>em$/`e'm<em>/;                                          # pojmem
    $diff =~ s/`u'<e>m$/`um'<em>/;                                        # kritériem

    # kdokoliv - komukoliv/kohokoliv
    $diff =~ s/k`d'o<(mu|ho)>(?=.+)/k`do'<o$1>/;

    # švec - ševce, vejce - vajec, žábry - žaber
    $diff =~ s/(?<=[^>'])`v'e<v>(?<=[^`<])/`ve'<ev>/;
    $diff =~ s/(?<=[^>'])`c'e<c>$/`ce'<ec>/;
    $diff =~ s/(?<=[^>'])<e>r`y'$/`ry'<er>/;

    #  TODO possibly allow more changes in the middle ?
    #    if ( $diff =~ m/[^><'`](<[^>]+>|`[^']+'){1,2}[^><'`]+(<[^>]+>|`[^']+'){1,2}[^><'`]/ ) {
    #        log_warn join " ", ( "PROBLEM: ", $lemma, $form, $diff, "\n" );
    #    }

    # find the changes in the diff
    my ( $front, $mid, $back ) = ( '', '', '' );

    # no change
    if ( $diff !~ m/[`'<>]/ ) {
        $back = '';
    }

    # everything changed
    elsif ( $diff =~ m/^`[^']*'/ || $lemma =~ /^($IRREGULAR_LEMMAS)$/ ) {
        $back = '*' . $form;
    }

    # just something has changed
    else {

        # change at the end
        if ( $diff =~ m/(?:`([^']+)')?(?:<([^>]+)>)?$/ && ( $1 // $2 ) ) {
            my $len = length( $1 // '' );
            my $add = $2 // '';
            $back = '>' . $len . $add;
        }

        # changing the last vowel
        if ( $diff =~ m/([^'`<>])(?:`([^']+)'|<([^>]+)>){1,2}[^'`<>]+/ && ( $2 // $3 ) ) {
            my $orig = $2 // '';
            my $new  = $3 // '';
            if ( !defined($2) ) {
                $orig = $1;
                $new  = $1 . $3;
            }
            $mid = $orig . '-' . $new;
        }

        # something added to the beginning
        if ( $diff =~ m/^<([^>]*)>/ ) {
            $front = '<' . $1;
        }
    }

    # prepare return value(s)
    my @ret;
    if ( $self->split_parts eq 'no' ) {
        push @ret, join( ',', grep { $_ ne '' } $back, $mid, $front );
    }
    elsif ( $self->split_parts eq 'front' ) {
        push @ret, join( ',', grep { $_ ne '' } $back, $mid );
        push @ret, $front;
    }
    else {
        push @ret, $back, $mid, $front;
    }

    if ( $self->output_diff ) {
        push @ret, $diff;
    }
    return @ret;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::LemmaFormDiff

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::LemmaFormDiff->new();
    
    print $modif->modify_all('starosta', 'starosty');  # '>1y'
    print $modif->modify_all('stůl', 'stolu');  # '>u,ů-o'    
    print $modif->modify_all('stolek', 'stolku'); # '>u,e-'
    print $modif->modify_all('matka', 'matek'); # '>1,-e'    
    print $modif->modify_all('hezký', 'nejhezčí'); # '<nej,>2čí'
    print $modif->modify_all('být', 'je'); # '*je'
    print $modif->modify_all('slovo', 'slovo'); # ''
    

=head1 DESCRIPTION

Given a lemma and one of its forms, return the differences between 
the lemma and the form (i.e. how to obtain the form from the lemma).

=head1 SETTINGS

TODO

=head1 NOTES

Some words had to be hard-set as irregular.

Only "legal" prefixes should be: nejne, ne, nej, po, pů


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.
