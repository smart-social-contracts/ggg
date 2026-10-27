export const idlFactory = ({ IDL }) => {
  const Value = IDL.Rec();
  Value.fill(
    IDL.Variant({
      'Int' : IDL.Int,
      'Map' : IDL.Vec(IDL.Tuple(IDL.Text, Value)),
      'Nat' : IDL.Nat,
      'Blob' : IDL.Vec(IDL.Nat8),
      'Text' : IDL.Text,
      'Array' : IDL.Vec(Value),
    })
  );
  const OperationArgs = IDL.Record({
    'op' : IDL.Text,
    'args' : Value,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const GggError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
    'NotFound' : IDL.Null,
    'Unsupported' : IDL.Text,
    'InvalidArgument' : IDL.Text,
    'Unavailable' : IDL.Text,
    'Forbidden' : IDL.Record({
      'permission' : IDL.Opt(IDL.Text),
      'message' : IDL.Text,
    }),
    'Unauthenticated' : IDL.Null,
    'Conflict' : IDL.Text,
  });
  const RunResult = IDL.Variant({ 'Ok' : Value, 'Err' : GggError });
  const Operation = IDL.Record({
    'permission' : IDL.Opt(IDL.Text),
    'signing' : IDL.Bool,
    'name' : IDL.Text,
    'provided_by' : IDL.Text,
    'read' : IDL.Bool,
    'result_schema' : IDL.Opt(IDL.Text),
    'description' : IDL.Text,
    'delegable' : IDL.Bool,
    'governed' : IDL.Bool,
    'args_schema' : IDL.Opt(IDL.Text),
  });
  const OperationResult = IDL.Variant({
    'Ok' : IDL.Opt(Operation),
    'Err' : GggError,
  });
  const ListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const OperationPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Operation),
  });
  const OperationsResult = IDL.Variant({
    'Ok' : OperationPage,
    'Err' : GggError,
  });
  const SupportedStandard = IDL.Record({ 'url' : IDL.Text, 'name' : IDL.Text });
  return IDL.Service({
    'ggg2_call' : IDL.Func([OperationArgs], [RunResult], []),
    'ggg2_operation' : IDL.Func([IDL.Text], [OperationResult], ['query']),
    'ggg2_operations' : IDL.Func([ListArgs], [OperationsResult], ['query']),
    'ggg2_query' : IDL.Func([OperationArgs], [RunResult], ['query']),
    'icrc10_supported_standards' : IDL.Func(
        [],
        [IDL.Vec(SupportedStandard)],
        ['query'],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
