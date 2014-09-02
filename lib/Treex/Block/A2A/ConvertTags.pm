package Treex::Block::A2A::ConvertTags;

use Moose;
use Treex::Core::Common;
use Lingua::Interset qw(decode encode);

extends 'Treex::Core::Block';

has 'input_driver' => ( isa => 'Str', is => 'ro', required => 1 );

has 'output_driver' => ( isa => 'Str', is => 'ro', default => '' );

has 'overwrite' => ( isa => 'Bool', is => 'ro', default => 0 );

sub process_anode {

    my ( $self, $anode ) = @_;
    return if ( !defined( $anode->tag ) );

    my $f = decode( $self->input_driver, $anode->tag );
    $anode->set_iset($f);

    if ( $self->output_driver ) {
        my $output_tag;

        if ( $self->output_driver eq 'cs::pdt' ) {    # TODO fix this, so it works normally
            $output_tag = encode( 'cs::pdt', $f, 1 );
        }
        else {
            $output_tag = encode( $self->output_driver, $f );
        }

        if ( $self->overwrite ) {
            $anode->wild->{orig_tag} = $anode->tag;
            $anode->set_tag($output_tag);
        }
        else {
            my $attribute_name = 'tag_' . $self->output_driver;
            $attribute_name =~ s/:+/_/g;
            $anode->wild->{$attribute_name} = $output_tag;
            #log_info( $anode->tag . ' / ' . $anode->wild->{tag_cs_pdt} . ' / ' . $anode->form );
        }

    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::ConvertTags

=head1 DESCRIPTION

Converting tags using Lingua::Interset.

If the C<output_driver> and C<overwrite> parameters are set, 
the tag value of a-nodes is replaced by the conversion and the original 
tag is stored in C<wild->orig_tag>.

If only C<output_driver> is set, the converted tag is stored in C<wild->tag_lang_driver>
(e.g. C<wild->tag_cs_pdt>).
 
If C<output_driver> is not set, only the C<iset> structure is filled in. 

=head1 PARAMETERS

=over

=item C<input_driver>

The Interset driver to be used on the input.

=item C<output_driver>

The Interset driver to be used on the output.

=item C<overwrite>

Indicates that the original tag should be overwritten by the converted tag.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
