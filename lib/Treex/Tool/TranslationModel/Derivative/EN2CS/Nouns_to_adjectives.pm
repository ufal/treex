package Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use Treex::Core::Common;
use Class::Std;
use Treex::Tool::Lexicon::Derivations::CS;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

{
    sub get_translations {
        my ($self, $input_label) = @_;
        my @cs_adjectives;

        foreach my $cs_entry ($self->get_base_model->get_translations($input_label)) {
            if ($cs_entry->{label} =~ /(.+)#N$/) {
                my $cs_noun = $1;
                push @cs_adjectives, map {
                                        { prob   => $cs_entry->{prob},
                                          label  => "$_#A",
                                          source => 'derivative_noun2adj',
                                        }
                                    } Treex::Tool::Lexicon::Derivations::CS::noun2adj($cs_noun);
            }
        }
        return @cs_adjectives;
    }
}

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Nouns_to_adjectives


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2010 David Marecek
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
