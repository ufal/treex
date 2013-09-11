package Treex::Block::Print::CorefSentences;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+extension' => ( default => '.coref' );

override 'print_header' => sub {
    my ($self, $doc) = @_;
    print {$self->_file_handle} "#begin document " . $doc->full_filename . "\n";
};
override 'print_footer' => sub {
    my ($self, $doc) = @_;
    print {$self->_file_handle} "#end document " . $doc->full_filename . "\n";
};

sub process_atree {
    my ($self, $atree) = @_;
    my @nodes = $atree->get_descendants({ordered => 1});

    my @forms = map {_create_coref_str($_)} @nodes;
   
    my $str = $atree->get_address;
    $str =~ s/^.*_(\d+)##(\d+)\..*/$1_$2/;
    $str .= "\t";
    $str .= join " ", @forms;
    print { $self->_file_handle } "$str\n";
}

sub _create_coref_str {
    my ($anode) = @_;

    my @start = defined $anode->wild->{coref_mention_start} ? sort {$a <=> $b} @{$anode->wild->{coref_mention_start}} : ();
    my @end = defined $anode->wild->{coref_mention_end} ? sort {$a <=> $b} @{$anode->wild->{coref_mention_end}} : ();

    my $str = join "", map {"[$_ "} @start;
    $str .= $anode->form;
    $str .= "]"x(scalar @end);
    
    return $str;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::CorefSentences

=head1 DESCRIPTION


=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
