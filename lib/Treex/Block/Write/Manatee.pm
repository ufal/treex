package Treex::Block::Write::Manatee;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Data::Dumper;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language'                        => ( required => 1 );
has 'deprel_attribute'                 => ( is       => 'rw', isa => 'Str', default => 'afun' );
has 'pos_attribute'                    => ( is       => 'rw', isa => 'Str', default => 'tag' );
has 'is_member_within_afun'            => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_shared_modifier_within_afun'   => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_coord_conjunction_within_afun' => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'randomly_select_sentences_ratio'  => ( is       => 'rw', isa => 'Num',  default => 1 );

has '+extension' => ( default => '.vert' );

sub process_atree {
    my ( $self, $atree ) = @_;

    # if only random sentences are printed
    return if rand() > $self->randomly_select_sentences_ratio;
	
    foreach my $anode ( $atree->get_descendants( { ordered => 1 } ) ) {
        my ( $lemma, $pos, $deprel ) =
            map { $self->get_attribute( $anode, $_ ) }
            (qw(lemma pos deprel));        
    		# convert lemma to the basic form
		my $truncated_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $lemma, 1 );
		
        # append suffices to afuns
        my $suffix = '';
        $suffix .= 'M' if $self->is_member_within_afun            && $anode->is_member;
        $suffix .= 'S' if $self->is_shared_modifier_within_afun   && $anode->is_shared_modifier;
        $suffix .= 'C' if $self->is_coord_conjunction_within_afun && $anode->wild->{is_coord_conjunction};
        $deprel .= "_$suffix" if $suffix;
        my ($eparent) = $anode->get_eparents({or_topological=>1});
        my $ep_form = $eparent->form;
        my $ep_tag = $eparent->tag;
        my $ep_afun = $eparent->afun;
        my $e_parent_full_lemma = $eparent->lemma;
        my $ep_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $e_parent_full_lemma, 1 );    
        my $p_ord = $anode->get_parent->ord;
        my $p_form = $anode->get_parent->form;
        no warnings 'uninitialized';
        my $p_full_lemma = $anode->get_parent->lemma;
        my $p_lemma =  Treex::Tool::Lexicon::CS::truncate_lemma( $p_full_lemma, 1 );#TODO if parent is a root
        my $p_pos = $anode->get_parent->tag;#TODO set tag for parent of root to 'root'
        my $p_afun = $anode->get_parent->afun;
        # Make sure that values are not empty and that they do not contain spaces.
        my @values = ($anode->form, $truncated_lemma, $pos, $deprel, $p_form, $p_lemma, $p_pos, $p_afun, $ep_form, $ep_lemma, $ep_tag, $ep_afun);
        @values = map
        {
            my $x = $_ // '_';
            $x =~ s/^\s+//;
            $x =~ s/\s+$//;
            $x =~ s/\s+/_/g;
            $x = '_' if($x eq '');
            $x
        }
        (@values);
        print { $self->_file_handle } join( "\t", @values ) . "\n";
    }
    return;
}

sub get_attribute {
    my ( $self, $anode, $name ) = @_;
    my $from = $self->{ $name . '_attribute' } || $name;    # TODO don't expect blessed hashref
    my $value = $anode->get_attr($from);
    return defined $value ? $value : '_';
}

#override 'print_header' => sub {
#        my ($self, $document) = @_;
#    print { $self->_file_handle } "<doc>\n";
#};

override 'process_bundle' => sub {
	my ($self, $bundle) = @_;	
	#my $position = $bundle->get_position()+1;
    print { $self->_file_handle } "<s>\n";# id=\"" . $position . "\">\n";
    $self->SUPER::process_bundle($bundle);    
    print { $self->_file_handle } "</s>\n";
};

#override 'print_header' => sub {
#	my ($self, $document) = @_;	
#    print { $self->_file_handle } "<doc id=\"" . $document->file_stem . "\">\n";         
#};

#override 'print_footer' => sub {
#	my ($self, $document) = @_;	
#    print { $self->_file_handle } "</doc>\n";    
#};

1;

__END__

=encoding utf8
=head1 NAME

Treex::Block::Write::Manatee

=head1 DESCRIPTION

Document writer for Manatee format, file with the following structure:

	<doc id="abc">
	<s id="1">
	token lemma POS-tag afun
	token lemma POS-tag afun
	...
	</s>
	<s id="2">
	token lemma POS-tag afun
	token lemma POS-tag afun
	...
	</s>
	...
	</doc>

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=item deprel_attribute

The name of attribute which will be printed into the 4th column (dependency relation).
Default is C<afun>.

=item pos_attribute

The name of attribute which will be printed into the 3rd column (part-of-speech tag).
Default is C<tag>.

=back

=head1 AUTHOR

David Mareček, Daniel Zeman, Martin Popel, Ondřej Dušek, Michal Josífko

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
