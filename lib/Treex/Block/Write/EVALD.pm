package Treex::Block::Write::EVALD;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

sub process_zone {
}

sub print_footer {
    my ($self, $doc) = @_;
      
    my $doczone = $doc->get_zone($self->language);

    print {$self->_file_handle} "EVALD RESULTS\n";
    print {$self->_file_handle} "----------------------------\n";

    my @SETS = qw(all spelling morphology vocabulary syntax connectives_quantity connectives_diversity coreference);
    foreach my $set (@SETS) {
        printf {$self->_file_handle} "feature set: %s\tclass:%s\tprobability: %.2f\n", $set, $doczone->get_attr("set_".$set."_evald_class"), $doczone->get_attr("set_".$set."_evald_class_prob");
    }
}

1;

__END__

=encoding utf-8


=head1 NAME

Treex::Block::Write::EVALD

=head1 DESCRIPTION

A console writer for EVALD results.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
