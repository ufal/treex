package Treex::Block::Test::FieldCanHaveWideChars;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'problematic_attribute' => ( is => 'rw', isa => 'Str', default => "žluťoučký kůň žvýkal ďábelského ťuhýka" );

1;
