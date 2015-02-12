package Treex::Tool::TranslationModel::Derivative::EN2CS::Numbers;
use Treex::Core::Common;
use Class::Std;
use Treex::Tool::Lexicon::EN;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

{
    sub get_translations {
        my ($self, $en_tlemma) = @_;

        my $cs_tlemma;

        if ( $en_tlemma =~ /(\d+)(st|nd|rd|th)$/ ) { # 1st -> 1. 2nd -> 2.
            $cs_tlemma = "$1.";
        }
        elsif ( $en_tlemma =~ /^\d+(,\d\d\d)*(\.\d+)?$/ ) {
            $cs_tlemma = $en_tlemma;
            $cs_tlemma =~ s/\.(\d+)$/,$1/;           # point goes to comma in Czech
            $cs_tlemma =~ s/(\d),(\d\d\d)/$1 $2/g;   # thousand separator is not a comma, but a space (ISO 31-0)

        }
        elsif ( $en_tlemma =~ /^(\p{isAlpha}+)-(\p{isAlpha}+)$/ ) {
            # forty-four -> 44 ( 'čtyřiačtyřicet' should be also implemented somewhere )
            my $first = Treex::Tool::Lexicon::EN::number_for($1);
            my $second = Treex::Tool::Lexicon::EN::number_for($2);
            if ( $first && $second ) {
                $cs_tlemma = $first + $second;
            }
        }

        if ( $cs_tlemma ) {
            return ( { prob => 1, label => "$cs_tlemma#C", source => 'Derivative::EN2CS::Numbers' } );
        }

        return;
    }
}
            

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Numbers

=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2010 David Marecek
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
