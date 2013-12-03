package Treex::Tool::Parser::MSTperl::Writer;

use Moose;
use autodie;
use Carp;

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

sub write_tsv {

    # (Str $filename,
    # ArrayRef[Treex::Tool::Parser::MSTperl::Sentence] $sentences)
    my ( $self, $filename, $sentences ) = @_;

    open my $file, '>:encoding(utf8)', $filename;
    foreach my $sentence ( @{$sentences} ) {
        foreach my $node ( @{ $sentence->nodes } ) {
            my @line = @{ $node->fields };

            # the parent_ord field contains -2 -> fill it with actual value
            # which is stored in $node->parentOrd
            $line[ $self->config->parent_ord_field_index ] =
                $node->parentOrd;

            # the label field contains '_' -> fill it with actual value
            # which is stored in $node->label
            my $label_field_index = $self->config->label_field_index;
            if ( defined $label_field_index ) {
                $line[$label_field_index] = $node->label;
            }

            print $file join "\t", @line;
            print $file "\n";
        }
        print $file "\n";
    }
    close $file;

    if ( -e $filename ) {
        return 1;
    } else {
        croak "MSTperl parser error:"
            . "unable to create the output file '$filename'!";
    }
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::Writer

=head1 DESCRIPTION

Writes L<Treex::Tool::Parser::MSTperl::Sentence> instances
to a CoNLL-like TSV file
(one line corresponds to one node, its features separated by tabs,
sentence boundary is represented by an empty line).

=head1 METHODS

=over 4

=item $reader->write_tsv($filename, $sentences)

Takes a reference to an array of sentences C<$sentences>
(instances of L<Treex::Tool::Parser::MSTperl::Sentence>)
and writes them to file C<$filename>.

The structure of the file (the order of the fields)
is determined by the C<config> field
(instance of L<Treex::Tool::Parser::MSTperl::Config>),
specifically by the C<field_names> setting.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
