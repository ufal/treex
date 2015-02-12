package Treex::Tool::TranslationModel::Derivative::EN2CS::Deadjectival_adverbs;
use Treex::Core::Common;
use Class::Std;
use Treex::Tool::Lexicon::Derivations::CS;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

{
    sub get_translations {
        my ($self, $input_label) = @_;
        my @cs_adverbs;

        if ($input_label =~ /(.+)ly$/) {
            my $en_adjective = $1;

            foreach my $cs_entry ($self->get_base_model->get_translations($en_adjective)) {

                if ($cs_entry->{label} =~ /(.+)#A$/) {
                    my $cs_adjective = $1;
                    push @cs_adverbs, map {
                        { prob => $cs_entry->{prob},
                              label => "$_#D",
                                  source => 'derivative_adj2adv'}}
                        Treex::Tool::Lexicon::Derivations::CS::adj2adv($cs_adjective);
                }
            }
        }
        return @cs_adverbs;
    }
}

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Deadjectival_adverbs


=head1 DESCRIPTION

Derivative translation dictionary for adverb regularly derived
from adjectives both in Czech and English:

en_adverb --> en_adjective --> cs_adjective --> cs_adverb


=head1 COPYRIGHT

Copyright 2010 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
