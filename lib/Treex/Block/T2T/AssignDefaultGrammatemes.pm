package Treex::Block::T2T::AssignDefaultGrammatemes;

use Moose;
use Treex::Core::Common;
use autodie;

extends 'Treex::Core::Block';

has 'grammateme_file' => ( isa => 'Str', is => 'ro' );

has 'grammatemes' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );


sub process_start {
    my ($self) = @_;
    
    open(my $fh, '<:utf8', $self->grammateme_file);
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