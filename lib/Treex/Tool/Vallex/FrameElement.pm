package Treex::Tool::Vallex::FrameElement;

use Moose;
use MooseX::ClassAttribute;
use Treex::Core::Common;

has 'functor' => ( isa => 'Str', is => 'ro', required => 1 );

has 'oblig' => ( isa => 'Bool', is => 'ro', required => 1 );

has 'forms' => ( isa => 'HashRef[Str]', is => 'ro' );

# loaded formeme conversion rules (from uc(language)/forms.txt), see _get_conversion_table
class_has '_loaded_conversion' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

around 'BUILDARGS' => sub {

    my $orig   = shift;
    my $self   = shift;
    my $params = $self->$orig(@_);    # Build a hashref

    if ( $params->{'xml'} ) {

        my $xml = $params->{'xml'};
        $params->{functor} = $xml->getAttribute('functor');
        $params->{oblig} = $xml->getAttribute('type') eq 'oblig';

        if ( $params->{functor} =~ /^(DPHR|CPHR|---)$/ ) {    # skip 'DPHR', 'CPHR' and '---' entries
            $params->{'forms'} = { '???' => 1 };
        }
        else {                                                # linearize forms -> build formemes
            $params->{'forms'} = {};
            foreach my $form ( $xml->getElementsByTagName('form') ) {

                my @form_list = _convert_formeme( $params->{language}, $form );
                map { $params->{'forms'}->{$_} = 1; } @form_list;
            }
        }
    }
    return $params;
};

sub has_form {

    my ( $self, $form ) = @_;

    return $self->forms->{$form} ? 1 : 0;
}

sub forms_list {

    my ($self) = @_;

    return [ keys %{ $self->forms } ];
}

sub to_string {
    my ($self, $params) = @_;
    my $ret = ( $self->oblig ? '' : '(' ) . $self->functor;
    if ($params and $params->{formemes}){
        $ret .= '[' . join( ', ', keys %{ $self->forms } ) . ']';
    }
    $ret .= ( $self->oblig ? '' : ')' );
    return $ret;
}

sub _convert_formeme {

    my ( $language, $form ) = @_;
    my $linear = _linearize($form);

    if ( $linear ne '' ) {
        my $conversion = _get_conversion_table($language);
        return split / /, $conversion->{$linear};
    }
    return ('???');
}

sub _get_conversion_table {

    my ($language) = @_;

    if ( !Treex::Tool::Vallex::FrameElement->_loaded_conversion->{$language} ) {

        my $file = __FILE__;
        $file =~ s/\/[^\/]*$//;
        $file .= '/' . uc($language) . '/forms.txt';
        my $conversion = {};

        open( my $fh, '<:utf8', $file );
        while ( my $line = <$fh> ) {

            $line =~ s/\r?\n//;
            my ( $old, $new ) = split( /\t/, $line, 2 );
            $conversion->{$old} = $new;
        }
        close($fh);

        Treex::Tool::Vallex::FrameElement->_loaded_conversion->{$language} = $conversion;
    }
    return Treex::Tool::Vallex::FrameElement->_loaded_conversion->{$language};
}

sub _linearize {

    my ($form) = @_;
    my $linear = $form->localname eq 'node' ? _get_name($form) : '';
    my @children = $form->getChildrenByTagName('node');

    if ( @children > 0 ) {
        my $lin_children = join( '_', map { _linearize($_) } @children );
        $linear = $linear eq '' ? $lin_children : $linear . '(' . $lin_children . ')';
    }

    return $linear;
}

sub _get_name {

    my ($node) = @_;

    if ( $node->getAttribute('lemma') ) {
        return $node->getAttribute('lemma');
    }
    elsif ( $node->getAttribute('pos') ) {
        return uc( $node->getAttribute('pos') . ( $node->getAttribute('case') ? ':' . $node->getAttribute('case') : '' ) );
    }
    elsif ( $node->getAttribute('case') ) {
        return $node->getAttribute('case');
    }
    else {
        return '???';
    }
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Vallex::FrameElement

=head1 DESCRIPTION

This object represents a single element of a L<Treex::Tool::Vallex::ValencyFrame>, storing its functor, obligatoriness and 
possible surface realizations (as TectoMT-style formemes).

=head1 SYNOPSIS

    # create a frame element from scratch
    my $el = Treex::Tool::Vallex::FrameElement->new({functor => 'ACT', oblig => 1, forms => {'n:1' => 1} });
    
    my $bool = $el->has_form('n:2');
    my @forms = $el->forms_list();
    
    # convert to string 
    print $el->to_string();

=head1 METHODS

=over

=item C<functor>

The functor of this valency frame.

=item C<forms>

A hashref containing all the possible surface realizations (TectoMT-style formemes) as keys.

=item C<forms_list>

A list of all the possible surface realizations of this frame (TectoMT-style formemes).

=item C<has_form>

    $bool = $el->has_form('n:2');

This returns C<1> if the given surface realization (TectoMT formeme) is possible for this frame element.  

=item C<new>

    $el = Treex::Tool::Vallex::FrameElement->new({functor => 'ACT', oblig => 1, forms => {'n:1' => 1} });

This constructs a new frame element. The C<functor>, C<oblig> and C<forms> (as a hashref) are required.
Frame elements may also be constructed directly from the valency lexicon XML node (which is the way they are 
created when constructing whole valency frames from the lexicon).

=item C<oblig>

This returns C<1> if this frame element is marked as obligatory.

=item C<to_string($params)>

This converts the given frame element to a string form similar to the following example:

    (EFF[n:do+2, n:na+4])
    
The functor is stated at the beginning, followed by a comma-separated list of all possible formemes (surface
realizations) enclosed in square brackets. If the frame element is not obligatory, it is enclosed in round brackets
as a whole.

If C<$params> is set, it must be a HASHREF. If C<$params->{formemes}> is set to 0, the formemes will not be returned.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
