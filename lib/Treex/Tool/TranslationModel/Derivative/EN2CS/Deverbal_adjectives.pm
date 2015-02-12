package Treex::Tool::TranslationModel::Derivative::EN2CS::Deverbal_adjectives;
use Treex::Core::Common;
use utf8;
use Class::Std;
use Treex::Tool::Lexicon::Derivations::CS;
use Treex::Tool::EnglishMorpho::Lemmatizer;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

my $lemmatizer = Treex::Tool::EnglishMorpho::Lemmatizer->new();

{
    sub get_translations {
        my ($self, $input_label) = @_;
        my @cs_adjectives;

        if ($input_label =~ /(.+)ed$/) {
            my $en_verb = $lemmatizer->lemmatize( $input_label, 'VBN' );

            foreach my $cs_entry ($self->get_base_model->get_translations($en_verb)) {
                if ($cs_entry->{label} =~ /(.+)#V$/) {
                    my $cs_verb = $1;
                    push @cs_adjectives, map {
                                                 { prob   => $cs_entry->{prob},
                                                   label  => "$_#A",
                                                   source => 'derivative_verb2adj',
                                                 }
                                             } Treex::Tool::Lexicon::Derivations::CS::verb2adj($cs_verb);
                }
            }
        }
        elsif ($input_label =~ /(.+)able/) {
            my $en_verb = $1;
            $en_verb =~ s/i$/y/;
            foreach my $cs_entry ($self->get_base_model->get_translations($en_verb)) {
                if ($cs_entry->{label} =~ /(.+)#V$/) {
                    $cs_entry->{label} =~ s/t#V$/telný#A/;
                    push @cs_adjectives, $cs_entry;
                }
            }
        }

        return @cs_adjectives;
    }
}

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Deverbal_adjectives


=head1 DESCRIPTION

Derivative translation dictionary for adjectives regularly derived
from verbs both in Czech and English:

en_adjective --> en_verb --> cs_verb --> cs_adjective

=head1 COPYRIGHT

Copyright 2010 David Marecek

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
