package Treex::Core::TredView::AnnotationCommand;

use Treex::Core::Log;

sub run {
    my ( $command, $node ) = @_;

    my ( $short_command, $argument ) = split / /, $command;

    print "in AnnotationCommand1\n";

    if ( $short_command eq 'd' ) {
        print "in AnnotationCommand2\n";
        $node->set_conll_deprel($argument);
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Core::TredView::AnnotationCommand - simple command-line annotation interface

=head1 DESCRIPTION

This module allows to annotate Treex files in TrEd by means
of a simple text-based command language. Command line dialog
is invoked in the Treex entension after pressing space.

The command language will be specified in the future.
At this moment, the language supports only one command:
'd <deprel>', which fills the <deprel> value into the conll/deprel
attribute.

=head1 METHODS

=head2 Public methods

=over 4

=item run($command,$node)

=back

=head1 AUTHOR

Zdeněk Žabokrtský <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

