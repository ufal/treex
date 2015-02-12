package Treex::Tool::TranslationModel::Derivative::EN2CS::Hyphen_compounds;
use Treex::Core::Common;
use Class::Std;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::Lexicon::EN;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use utf8;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

my %TRANSLATE_SECOND = (
    "member"   => "členný",
    "year-old" => "letý",
    "year"     => "letý",
    "litre"    => "litrový",
    "meter"    => "metrový",
    "inch"     => "palcový",
    "hours"    => "hodinový",
    "hour"     => "hodinový",
    "thirds"   => "třetinový",
    "third"    => "třetinový",
    "fourths"  => "čtvrinový",
    "fourth"   => "čtvrtinový",
    "fifth"    => "pětinový",
    "fifths"   => "pětinový",
    "crown"    => "korunový",
    "dollar"   => "dolarový",
    "euro"     => "eurový",
    "voice"    => "hlasý",
);

my %TRANSLATE_FIRST = (
    "high" => "vysoko",
    "low"  => "nízko",
);

{

    our %noun2adj_model : ATTR;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;
        $noun2adj_model{$ident} = $arg_ref->{noun2adj_model} or log_fatal "'noun2adj_model' must be defined";
        return $self;
    }

    sub get_noun2adj_model {
        my ($self) = @_;
        return $noun2adj_model{ ident $self};
    }

    sub get_translations {
        my ( $self, $input_label ) = @_;

        return if $input_label !~ /^([^\-]+)-(.+)$/;

        my $first  = $1;
        my $second = $2;

        my $translated_first;
        if ( Treex::Tool::Lexicon::EN::number_for($first) ) {
            $translated_first = Treex::Tool::Lexicon::CS::numeral_prefix_for_number( Treex::Tool::Lexicon::EN::number_for($first) );
        }
        else {
            $translated_first = $TRANSLATE_FIRST{$first};
        }

        my @translations;
        if ( defined $translated_first ) {

            if ( $TRANSLATE_SECOND{$second} ) {
                @translations = (
                    {
                        'label'  => $translated_first . $TRANSLATE_SECOND{$second} . '#A',
                        'source' => 'Derivative::EN2CS::Hyphen_compounds',
                        'prob'   => 0.5,
                    }
                );
            }
            else {
                @translations = map { $_->{label} = $translated_first . $_->{label}; $_ } $self->get_noun2adj_model->get_translations($second);
            }

            #            push @translations, { prob   => 0.2,
            #                                  label  => $number_for_first . $translation_for_second . "#A",
            #                                  source => 'Derivative::EN2CS::Hyphen_compounds',
            #                                };
        }
        elsif ( $second =~ /^(based|wise)$/ ) {
            @translations = $self->get_noun2adj_model->get_translations($first);
        }

        return @translations;
    }
}

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Hyphen_compounds


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2010 David Marecek
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
