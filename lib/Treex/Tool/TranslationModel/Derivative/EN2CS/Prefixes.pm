package Treex::Tool::TranslationModel::Derivative::EN2CS::Prefixes;
use Treex::Core::Common;
use Class::Std;
use utf8;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

use Treex::Tool::Lexicon::Generation::CS;
my $generator = Treex::Tool::Lexicon::Generation::CS->new();

# TODO
# ante bi cyber extra infra macro mega meta mid over un under
# suffix -fold
my %ENPREFIX_TO_CSPREFIX = (
    "anti"    => [qw(proti anti)],
    "auto"    => [qw(auto)],
    "bio"     => [qw(bio)],
    "co"      => [qw(spolu sou ko s)],
    "com"     => [qw(spolu sou kom s)],
    "con"     => [qw(spolu sou kon s)],
    "counter" => [qw(proti)],
    "de"      => [qw(od)],
    ##"ex"      => [qw(ex)], better translated in Translate_LF_compounds as "bývalý"
    "euro"   => [qw(euro)],
    "hyper"  => [qw(hyper)],
    "inter"  => [qw(mezi)],
    "intra"  => [qw(intra)],
    "iso"    => [qw(stejno)],
    "maxi"   => [qw(maxi)],
    "mini"   => [qw(mini)],
    "micro"  => [qw(mikro)],
    "multi"  => [qw(více multi)],
    "mono"   => [qw(jedno mono)],
    "neo"    => [qw(novo neo)],
    "non"    => [qw(non ne)],
    "no"     => [qw(ne)],
    "nano"   => [qw(nano)],
    "pan"    => [qw(vše celo)],
    "para"   => [qw(para)],
    "post"   => [qw(po)],
    "pre"    => [qw(před)],
    "pro"    => [qw(pro)],
    "proto"  => [qw(proto)],
    "pseudo" => [qw(pseudo)],
    "poly"   => [qw(mnoho)],
    "re"     => [qw(znovu re)],
    "self"   => [qw(sebe)],
    "semi"   => [qw(polo)],
    "sub"    => [qw(pod)],
    "super"  => [qw(nad)],
    "supra"  => [qw(supra)],
    "trans"  => [qw(trans přes)],
    "ultra"  => [qw(ultra)],
    "vice"   => [qw(vice)],
);

my %ENPARTICLE_TO_CSPREFIX = (
    out => [ 'vy', '' ],
    off => [ 'z', 'se', '' ],
    down => [''],
    up   => [''],
    on   => [''],
    across => [''],
    through => ['pro',''],
);

sub get_translations {
    my ( $self, $en_lemma, $features_array_rf ) = @_;

    # Don't translate named entities (Intermoney -> Mezipeníze)
    return if grep {/^ne_type/} @{$features_array_rf};
    my ( $prefix, $hyphen, $rest );
    foreach my $pr ( keys %ENPREFIX_TO_CSPREFIX ) {
        if ( $en_lemma =~ /^($pr)(-?)(...+)$/ ) {
            my @t = translate_prefixes_separately( $self, $1, $2, $3 );
            return @t if @t;
        }
    }

    if ( !$self->get_base_model->get_translations($en_lemma) ) {
        foreach my $particle ( keys %ENPARTICLE_TO_CSPREFIX ) {
            if ( $en_lemma =~ /^(..+)_($particle)$/ ) {
                return translate_particles_separately( $self, $1, $2 );
            }
        }
    }

    return ();
}

sub translate_prefixes_separately {
    my ( $self, $prefix, $hyphen, $rest ) = @_;

    my @translations_of_the_rest = $self->get_base_model->get_translations($rest);
    my @translations             = ();

    foreach my $translation (@translations_of_the_rest) {
        my $cs_suffix = $translation->{label};
        $cs_suffix =~ s/#.$//;
        my $new_prob = $translation->{prob} / 20;
        foreach my $cs_prefix ( @{ $ENPREFIX_TO_CSPREFIX{$prefix} } ) {
            my @analyses = $generator->forms_of_lemma( $cs_prefix . $cs_suffix, { tag_regex => '^[NADV]', guess => 0 } );
            push @translations, {
                prob => @analyses ? $new_prob : $new_prob / 10,
                label  => $cs_prefix . $translation->{label},
                source => 'Derivative::EN2CS::Prefixes',
            };
            $new_prob *= 0.95;
        }
    }
    return @translations;
}

sub translate_particles_separately {
    my ( $self, $word, $particle ) = @_;

    my @translations = ();
    foreach my $translation ( $self->get_base_model->get_translations($word) ) {
        foreach my $cs_prefix ( @{ $ENPARTICLE_TO_CSPREFIX{$particle} } ) {
            my $new_label = $cs_prefix . $translation->{label};
            my $new_word  = $new_label;
            $new_word =~ s/#.$//;
            my @analyses = $generator->forms_of_lemma( $new_word, { tag_regex => '^[NADV]', guess => 0 } );
            if (@analyses) {
                push @translations, {
                    prob   => $translation->{prob} / 20,
                    label  => $new_label,
                    source => 'Derivative::EN2CS::Prefixes',
                };
            }
        }
    }

    return @translations;
}

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Prexixes


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2010 David Marecek, Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
