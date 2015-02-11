package Treex::Tool::LM::FormInfo;

use strict;
use warnings;
use utf8;

use Class::Std;

my %tag_of : ATTR( :name<tag> );
my %lemma_of : ATTR( :name<lemma> );
my %form_of : ATTR( :name<form> );
my %count_of : ATTR( :name<count> :default<0>);
my %origin_of : ATTR( :name<origin> :default<> );

sub to_string : STRINGIFY {
    my ($self) = @_;
    my $id = ident $self;
    return join "\t",
        'form: ' . $form_of{$id},
        'tag: ' . $tag_of{$id},
        'lemma: ' . $lemma_of{$id},
        $count_of{$id} ? 'count:' . $count_of{$id} : '',
        $origin_of{$id} ? 'origin:' . $origin_of{$id} : '';
}

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
