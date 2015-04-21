package Treex::Tool::LM::FormInfo;
#use Moo;
use strict;
use warnings;

sub new {
    my ( $class, $hashref ) = @_;
    return bless $hashref, $class;
}

sub get_tag {return $_[0]->{tag};}
sub get_lemma {return $_[0]->{lemma};}
sub get_form {return $_[0]->{form};}
sub get_count {return $_[0]->{count} || 0;}
sub get_origin {return $_[0]->{origin} // '';}

sub set_tag {$_[0]->{tag} = $_[1];}
sub set_lemma {$_[0]->{lemma} = $_[1];}
sub set_form {$_[0]->{form} = $_[1];}
sub set_count {$_[0]->{count} = $_[1];}
sub set_origin {$_[0]->{origin} = $_[1];}


sub to_string {
    my ($self) = @_;
    return join "\t",
        'form: ' . $self->{form},
        'tag: ' . $self->{tag},
        'lemma: ' . $self->{lemma},
        $self->{count} ? 'count:' . $self->{count} : '',
        $self->{origin} ? 'origin:' . $self->{origin} : '';
}

use overload '""' => \&to_string;

1;

__END__

=pod

=head1 NAME

Treex::Tool::LM::FormInfo  


=head1 VERSION

0.01

=head1 SYNOPSIS

 use Treex::Tool::LM::FormInfo;

 my $form_info = Treex::Tool::LM::FormInfo->new({
     lemma => 'moci',
     form  => 'mohou',
     tag   => 'VB-P---3P-AA--1I',
     count => 238013,
 });

 my ($form, $tag, $count) = (
    $form_info->get_form(),
    $form_info->get_tag(),
    $form_info->get_count());

=head1 DESCRIPTION

This class encapsulates attributes: lemma, form, tag, count.   
It is used in C<Treex::Tool::LM::MorphoLM>. 

=head1 AUTHORS

Martin Popel

=cut

# Copyright 2008 Martin Popel
