package Treex::Block::Write::Amr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.amr' );

has '+language' => (
    isa        => 'Maybe[Str]'
);

has '+selector' => (
    isa        => 'Maybe[Str]'
);

sub process_ttree {
    my ( $self, $ttree ) = @_;

    foreach my $ttop ($ttree->get_children({ordered=>1})){ 
        print { $self->_file_handle } '(' . $ttop->t_lemma;
        foreach my $child ($ttop->get_children({ordered=>1})){
            $self->_process_tnode($child, '    ');
        }
        print { $self->_file_handle } ")\n";
    }
}

sub _process_tnode {
    my ( $self, $tnode, $indent ) = @_;
    my $lemma = $tnode->get_attr('t_lemma');
    $lemma =~ s/\// \/ /;
    if ($lemma) {
      print { $self->_file_handle } "\n" . $indent;
      my $modifier = $tnode->wild->{'modifier'} ? $tnode->wild->{'modifier'} : $tnode->functor;
      if ($modifier && $modifier ne "root" && $indent ne "") {
         print { $self->_file_handle } ':' . $modifier;
      }
      print { $self->_file_handle } " ("  . $lemma;
    }
    foreach my $child ($tnode->get_children({ordered=>1})){
        $self->_process_tnode($child, $indent . '    ');
    }
    print { $self->_file_handle } ")";
}


1;

__END__

=head1 NAME

Treex::Block::Write::Amr

=head1 DESCRIPTION

Document writer for amr-like format.

=head1 ATTRIBUTES

=over

=item language

Language of tree


=item selector

Selector of tree


=back

=head1 METHODS

=over

=back

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
