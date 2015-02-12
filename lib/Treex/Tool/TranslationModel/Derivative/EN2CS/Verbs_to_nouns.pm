package Treex::Tool::TranslationModel::Derivative::EN2CS::Verbs_to_nouns;
use Treex::Core::Common;
use Class::Std;
use Treex::Tool::Lexicon::Derivations::CS;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

{
    sub get_translations {
        my ($self, $input_label) = @_;
        my @cs_nouns;

        foreach my $cs_entry ($self->get_base_model->get_translations($input_label)) {
            if ($cs_entry->{label} =~ /(.+)#V$/) {
                my $cs_verb = $1;
                push @cs_nouns, map {
                                        { prob   => $cs_entry->{prob},
                                          label  => "$_#N",
                                          source => 'derivative_verb2noun',
                                        }
                                    } Treex::Tool::Lexicon::Derivations::CS::verb2noun($cs_verb);
            }
        }
        return @cs_nouns;
    }
}

1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Verbs_to_nouns


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2010 David Marecek
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
