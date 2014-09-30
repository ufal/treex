package Treex::Block::T2T::AssignDefaultGrammatemes;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use autodie;

extends 'Treex::Core::Block';

has 'grammateme_file' => ( isa => 'Str', is => 'ro' );

has 'grammatemes' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );


sub process_start {
    my ($self) = @_;

    my $gram_file = $self->grammateme_file;
    if (not -f $gram_file){
        $gram_file = Treex::Core::Resource::require_file_from_share($gram_file);
    }
    
    open(my $fh, '<:utf8', ( $gram_file ) );
    while (my $line = <$fh>){
        chomp $line;
        my ($key, $val) = split /\t/, $line;
        $self->grammatemes->{$key} = $val;
    }
    close($fh);
}

sub process_tnode {
    my ($self, $tnode) = @_;
    
    if ($self->grammatemes->{$tnode->t_lemma . " " . $tnode->formeme}){
        $self->_set_grams($tnode, $self->grammatemes->{$tnode->t_lemma . " " . $tnode->formeme});
    }
    elsif ($self->grammatemes->{$tnode->formeme}){
        $self->_set_grams($tnode, $self->grammatemes->{$tnode->formeme});
    }
}

sub _set_grams {
    my ($self, $tnode, $grams) = @_;
    
    foreach my $gram (split /\+/, $grams){
        my ($gram_type, $gram_val) = split /=/, $gram;
        $tnode->set_attr("gram/$gram_type", $gram_val); 
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::AssignDefaultGrammatemes

=head1 DESCRIPTION

Given a list of default grammatemes per t-lemma/formeme pair (backoff to formemes only), 
this will assign them to all matching nodes.

This is intended to be used with the Tgen generator output and the 
L<Treex::Block::Print::GrammatemesForTgen> block.

=head1 PARAMETERS

=over

=item grammateme_file

Path to the list of default grammatemes to be used. If the path is not valid as such,
it is searched in the Treex shared directory (and possibly downloaded from the web). 

=back

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
