package Treex::Block::A2A::ConvertTagsInterset;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'input_driver' => ( isa => 'Str', is => 'ro', required => 1 );

has 'output_driver' => ( isa => 'Str', is => 'ro', default => '' );

has 'overwrite' => ( isa => 'Bool', is => 'ro', default => 0 );

has '_in_driver' => ( is => 'ro', lazy_build => 1);
has '_out_driver' => ( is => 'ro', lazy_build => 1);

sub _build__in_driver {
    my ($self) = @_;
    my $driver_name = 'Treex::Tool::Interset::' . $self->input_driver;
    my $driver = eval "use $driver_name; $driver_name->new();";
    log_fatal "Cannot load $driver_name: $@" if !$driver;
    return $driver;
}

sub _build__out_driver {
    my ($self) = @_;
    my $driver_name = 'Treex::Tool::Interset::' . $self->output_driver;
    my $driver = eval "use $driver_name; $driver_name->new();";
    log_fatal "Cannot load $driver_name: $@" if !$driver;
    return $driver;
}


sub process_anode {
    my ( $self, $anode ) = @_;
    return if !defined $anode->tag;

    my $iset = $self->_in_driver->decode($anode->tag);
    $anode->set_iset($iset);

    if ( $self->output_driver ) {
        my $output_tag;
        $output_tag = $self->_out_driver->encode($iset);

        if ( $self->overwrite ) {
            $anode->wild->{orig_tag} = $anode->tag;
            $anode->set_tag($output_tag);
        }
        else {
            my $attribute_name = 'tag_' . $self->output_driver;
            $attribute_name =~ s/:+/_/g;
            $anode->wild->{$attribute_name} = $output_tag;
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::ConvertTagsInterset

=head1 SYNOPSIS

 A2A::ConvertTagsInterset input_driver=PT::Cintil

=head1 DESCRIPTION

Converting tags using DZ Interset.

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

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
