package Treex::Tool::Interset::Driver;
use utf8;
use Moose::Role;

requires 'decoding_table';

has _encoding_table => (
    is => 'ro',
    lazy_build => 1,
);

sub _build__encoding_table {
    my ($self) = @_;
    my $decoding_table = $self->decoding_table;

    # For encoding purposes, sort the rules from the most complex (specific) ones.
    my @encoding_table =
        map {[$_->[0], $decoding_table->{$_->[0]}]}
        sort {$b->[1] <=> $a->[1]}
        map {[$_, scalar keys %{$decoding_table->{$_}}]}
        keys %$decoding_table;
        
    return \@encoding_table
}


sub driver_name {
    my ($self) = @_;
    my $class_name = ref $self;
    $class_name =~ s/^Treex::Tool::Interset:://;
    return $class_name;
}

sub BUILD {}
after BUILD => sub {
    my ($self) = @_;
    my $driver_name = $self->driver_name;
    my $decoding_table = $self->decoding_table;
    foreach my $tag ( keys %$decoding_table ) {
        $decoding_table->{$tag}{tagset} = $driver_name;
    }
    return;
};

sub decode {
    my ($self, $orig_tag) = @_;
    return $self->decoding_table->{$orig_tag};
}

sub encode {
    my ($self, $f) = @_;
    my ($max_tag, $max_matching) = (undef, 0);
    
    RULE:
    for my $rule (@{$self->_encoding_table}){
        my ($tag, $iset) = @$rule;
        
        # Check all features (keys) of $iset if they are satisfied by the $f structure.
        my ($matching, $missing) = (0,0);
        for my $key (keys %$iset){
            next if $key eq 'tagset'; # "tagset" feature is irrelevant
            if (exists $f->{$key} && $f->{$key} eq $iset->{$key}){
                $matching++;
            } else {
                $missing++;
            }
        }
        
        # If yes, we found the best matching tag.
        return $tag if $missing==0;
                
        
        # Otherwise, keep track of the $tag with the maximum number of matching features with $f
        if ($matching > $max_matching) {
            $max_matching = $matching;
            $max_tag = $tag;
        }
        
        # but don't return such tag if there are also other tags with the same number of matching features.
        elsif ($matching == $max_matching){
            $max_tag = undef;
        }
    }

    return $max_tag;
}

sub list {
    my ($self) = @_;
    return [keys %{$self->decoding_table}];
}

1;

__END__

=head1 NAME

Treex::Tool::Interset::Driver

=head1 SYNOPSIS
 
 package Treex::Tool::Interset::EN::TagSetName;
 use Moose;
 with 'Treex::Tool::Interset::Driver';

 # See https://wiki.ufal.ms.mff.cuni.cz/user:zeman:interset:features
 my $DECODING_TABLE = {
    A       => { pos => 'adj' },
    ART     => { pos => 'adj',  subpos => 'art' },
    CARD    => { pos => 'num',  numtype => 'card' },
    # etc.
 };

 sub decoding_table {
    return $DECODING_TABLE;
 }

 1;
 # That's all. You've got methods decode() and encode() for free.

=head1 DESCRIPTION

This role helps building Interset drivers for tagsets with a small number of tags.
For tagsets with a higher number of tags that have some system in the naming(positional tags),
it is better to implement methods decode() and encode() directly using this extra knowledge.

=head1 METHODS

=head2 Methods required to be defined

=head3 decoding_table

Should return a hashref mapping tags to Interset structures.
See the SYNOPSIS.
You don't need to include "tagset" features with the name of the tagset,
they will be added automatically.

=head2 Methods that may be redefined

=head3 driver_name

Name of the driver to be included in the "tagset" feature.
By default the name is derived from the package/class name
by deleting the "Treex::Tool::Interset::" prefix.

=head2 Methods provided by this role

=head3 my $iset = $driver->decode($tag)

Convert (original) tag into Interset structure $iset.
The default implementation is based on the values in C<decode_table>.

=head3 my $tag = $driver->encode($iset)

Convert Interset structure $iset into a tag.
The default implementation kindof inverts the "rules" in the C<decode_table>.
First, it tries to find the most specific rule that is fully "satisfied" by the given C<$iset>.
If no such rule exists, it tries to find a rule with a highest overlap
(number of matching features) with the given C<$iset>.

=head3 my $list_ref = $driver->list()

List of possible tags.

=head1 SEE ALSO

L<Treex::Block::Print::IntersetDriverStub> -- generates a base source code of a driver based on morphological tags occuring in a given Treex document.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
